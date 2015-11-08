#!/usr/bin/env ruby
require 'optparse'
require 'resolv'
require './vagrant_whisperer'
require './packet_inspector'
require './inspect_config'
require './utils'

options = {
  rollback: true
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage #{File.basename($0)} [options] <git repo URL>"
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end

  opts.on('-n', '--no-rollback #',
          "Don't rollback the virtual machine's state after running") do
    options[:rollback] = false
  end
end

optparse.parse!

if ARGV.size < 1
  puts 'Must specifiy a repo URL'
  puts optparse.help
  exit -1
end

repo_url = ARGV[0]
repo_name = repo_url.split('/').last.chomp('.git')

commands = []

REPO_DIR = "~/repo"
# Clone repo
commands << "git clone #{repo_url} #{REPO_DIR}"
commands << "cd #{REPO_DIR}"

$config = InspectConfig.new
$whisperer = VagrantWhisperer.new

# Upload filelist of directories to include and exclude for rdiff-backup
filelist = 'filelist'
filelist_remote_path = File.join($whisperer.home, filelist)
File.open filelist, 'w' do |f|
  f.write($config.filelist.gsub(/\$HOME/, $whisperer.home))
end
$whisperer.sendFile(filelist, filelist_remote_path)

get_proc = 'get_processes_job.rb'
remote_get_proc = File.join($whisperer.home, get_proc)
$whisperer.sendFile(get_proc, remote_get_proc)

# Add repo to backup so we can diff later
commands << 'echo Preparing file system snapshot ...'
commands << "sudo rdiff-backup --include-filelist #{filelist_remote_path} / #{VagrantWhisperer::BACKUP_DIR}"

commands << 'echo "Starting network monitoring ..."'
commands << "sudo tcpdump -w #{VagrantWhisperer::EVIDENCE_DIR}/evidence.pcap -i eth0 &disown"

commands << "ruby #{remote_get_proc} &disown"

commands << 'sleep 1'

# script can be a string or an array of strings
commands = (commands + [$config.script]).flatten

$whisperer.runCommands(commands)

commands.clear
commands << 'pkill ruby'
commands << 'sudo pkill tcpdump'
get_current_mirror = "`sudo rdiff-backup --list-increments #{VagrantWhisperer::BACKUP_DIR} |  awk -F\": \" '$1 == \"Current mirror\" {print $2}'`"
commands << "sudo rdiff-backup --include-filelist #{filelist_remote_path} --compare-at-time \"#{get_current_mirror}\" / #{VagrantWhisperer::BACKUP_DIR} > #{VagrantWhisperer::EVIDENCE_DIR}/fs-diff.txt"
commands << %Q~ruby -e 'IO.readlines("/evidence/fs-diff.txt").each { |e| puts e; o,f = e.strip.split(": "); puts `diff -u /backup/\#{f} /\#{f} ` if o.eql?("changed") && File.exists?("/"+f) && !File.directory?("/"+f)}' > #{VagrantWhisperer::EVIDENCE_DIR}/fs-diff-with-changes.txt~

$whisperer.runCommands(commands)

puts 'Zipping and downloading evidences from vagrant image...'
include Utils
zipfile = "#{timestamp}-#{repo_name}-evidence.zip"
$local_evidence_dir = zipfile.chomp '.zip'
$whisperer.collectEvidence(into = zipfile)
unzip zipfile, $local_evidence_dir

KILOBYTE = 1024.0

def prettify(size)
  return size.to_s + 'B' if size < 1000
  (size / KILOBYTE).round(1).to_s + 'K'
end

def print_outgoing_connections(pcap_file)
  vagrant_ip = $whisperer.ip_address
  packet_inspector = PacketInspector.new pcap_file
  outgoing_packets = packet_inspector.packets_from vagrant_ip

  ips_sizes = outgoing_packets.each_with_object(Hash.new(0)) do |packet, memo|
    memo[packet.ip_dst_readable] += packet.size
  end

  dns_responses = packet_inspector.dns_responses
  address_to_name = dns_responses.each_with_object({}) do |name_addresses, memo|
    name = name_addresses.first
    addresses = name_addresses.last
    addresses.each { |address| memo[address.to_s] = name }
  end

  whitelist = $config.whitelist

  # whitelist the dns' ip as we wouldn't want it to show up
  dns_server = Resolv::DNS::Config.default_config_hash[:nameserver]
  whitelist += dns_server if dns_server

  not_in_whitelist = ips_sizes.map { |ip, size| [address_to_name.fetch(ip, ip), ip, size] }
                              .find_all { |hostname, ip, size| !(whitelist.include?(hostname) || whitelist.include?(ip)) }
  return if not_in_whitelist.empty?

  puts "The following hostnames were reached during the build process:"
  not_in_whitelist.each do |hostname, ip, size|
    name_ip = "#{hostname} (#{ip})".ljust(60)
    puts "  #{name_ip} #{prettify(size).rjust(10)}"
  end
end

def print_fs_changes
  diff_file = File.join($local_evidence_dir, 'evidence', 'fs-diff-with-changes.txt')
  File.foreach(diff_file) { |x| puts x }
end

def print_processes
  ps_dir = File.join($local_evidence_dir, 'evidence', 'ps')
  procs = []
  Dir.foreach(ps_dir) do |filename|
    next if filename == '.' || filename == '..'
    contents = YAML.load_file(File.join(ps_dir, filename))
    procs << contents if contents
  end
  return if procs.empty?
  puts 'The following processes were running during the build:'
  procs.flatten.each do |proc|
    puts "  - #{proc}"
  end
end

pcap_file = File.join $local_evidence_dir, 'evidence', 'evidence.pcap'
print_outgoing_connections pcap_file
print_fs_changes
print_processes

puts 'Rolling back virtual machine state...'
`vagrant sandbox rollback` if options[:rollback]
