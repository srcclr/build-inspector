#!/usr/bin/env ruby
require 'optparse'
require 'resolv'
require 'terminal-table'
require 'rainbow'
require './vagrant_whisperer'
require './packet_inspector'
require './inspect_config'
require './utils'

$stdout.sync = true

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
  exit(-1)
end
`vagrant sandbox on`

repo_url = ARGV[0]
repo_name = repo_url.split('/').last.chomp('.git')
REPO_DIR = "~/repo"

$config = InspectConfig.new
$whisperer = VagrantWhisperer.new

# Upload filelist of directories to include and exclude for rdiff-backup
filelist = 'filelist'
filelist_remote_path = File.join($whisperer.home, filelist)
File.open filelist, 'w' do |f|
  f.write($config.filelist.gsub(/\$HOME/, $whisperer.home))
end
$whisperer.sendFile(filelist, filelist_remote_path)
`rm #{filelist}`

$whisperer.run desc: "Cloning #{repo_url} ..." do |commands|
  commands << "git clone #{repo_url} #{REPO_DIR}"
end

$whisperer.run desc: 'Preparing file system snapshot ...' do |commands|
  commands << "sudo rdiff-backup --include-filelist #{filelist_remote_path} / #{VagrantWhisperer::BACKUP_DIR}"
end

$whisperer.run desc: 'Starting network monitoring ...' do |commands|
  commands << "sudo tcpdump -w #{VagrantWhisperer::EVIDENCE_DIR}/evidence.pcap -i eth0 > /dev/null &disown"
  commands << "ps --sort=lstart -eott,cmd > #{VagrantWhisperer::EVIDENCE_DIR}/ps-before.txt"
end

$whisperer.run desc: 'Starting build ...' do |commands|
  commands << "cd #{REPO_DIR}"
  commands.concat([$config.script]).flatten # $config.script may be a list
  commands << Utils.yell('Done. Your build exited with $?.')
end

$whisperer.run desc: 'Comparing file system snapshots ...' do |commands|
  commands << 'sudo pkill tcpdump'
  commands << "ps --sort=lstart -eott,cmd > #{VagrantWhisperer::EVIDENCE_DIR}/ps-after.txt"
  get_current_mirror = "`sudo rdiff-backup --list-increments #{VagrantWhisperer::BACKUP_DIR} |  awk -F\": \" '$1 == \"Current mirror\" {print $2}'`"
  commands << "sudo rdiff-backup --include-filelist #{filelist_remote_path} --compare-at-time \"#{get_current_mirror}\" / #{VagrantWhisperer::BACKUP_DIR} > #{VagrantWhisperer::EVIDENCE_DIR}/fs-diff.txt"
  commands << %Q~ruby -e 'IO.readlines("/evidence/fs-diff.txt").each { |e| puts e; o,f = e.strip.split(": "); puts `diff -u /backup/\#{f} /\#{f} ` if o.eql?("changed") && File.exists?("/"+f) && !File.directory?("/"+f)}' > #{VagrantWhisperer::EVIDENCE_DIR}/fs-diff-with-changes.txt~
end

puts Utils.yellowify('Zipping and downloading evidences from vagrant image ...')
zipfile = "#{Utils.timestamp}-#{repo_name}-evidence.zip"
$local_evidence_dir = zipfile.chomp '.zip'
$whisperer.collectEvidence(into = zipfile)
Utils.unzip zipfile, $local_evidence_dir

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

  puts Utils.yellowify('The following hostnames were reached during the build process:')
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
  puts Utils.yellowify('The following processes were running during the build:')
  procs.flatten.each do |proc|
    puts "  - #{proc}"
  end
end

pcap_file = File.join $local_evidence_dir, 'evidence', 'evidence.pcap'
print_outgoing_connections pcap_file
print_fs_changes
print_processes

if options[:rollback]
  puts Utils.yellowify('Rolling back virtual machine state...')
  Utils.exec_puts 'vagrant sandbox rollback'
end
