require 'resolv'
require_relative 'build_inspector'

class EvidenceProcessor
  KILOBYTE = 1024.0

  def initialize(evidence_path:, vagrant_ip:, host_whitelist:)
    @evidence_path = File.join(evidence_path, 'evidence')
    @vagrant_ip = vagrant_ip
    @host_whitelist = host_whitelist
  end

  def process
    print_processes
    print_connections
    print_filesystem_changes
    print_running_processes
  end

  private

  def print_rocesses
    # open and parse snoopy file
  end

  def print_connections
    pcap_file = File.join(@evidence_path, BuildInspector::PCAP_FILE)
    packet_inspector = PacketInspector.new(pcap_file)
    outgoing_packets = packet_inspector.packets_from(@vagrant_ip)

    ips_sizes = outgoing_packets.each_with_object(Hash.new(0)) do |packet, memo|
      memo[packet.ip_dst_readable] += packet.size
    end

    dns_responses = packet_inspector.dns_responses
    address_to_name = dns_responses.each_with_object({}) do |name_addresses, memo|
      name = name_addresses.first
      addresses = name_addresses.last
      addresses.each { |address| memo[address.to_s] = name }
    end

    # Whitelist the DNS' IP also; don't want it showing up
    dns_server = Resolv::DNS::Config.default_config_hash[:nameserver]
    whitelist = @host_whitelist
    whitelist += dns_server if dns_server

    not_in_whitelist = ips_sizes.map { |ip, size| [address_to_name.fetch(ip, ip), ip, size] }
                                .find_all { |hostname, ip, size| !(whitelist.include?(hostname) || whitelist.include?(ip)) }
    return if not_in_whitelist.empty?

    puts Printer.yellowify('Hosts contacted during the build:')
    not_in_whitelist.each do |hostname, ip, size|
      name_ip = "#{hostname} (#{ip})".ljust(60)
      puts "  #{name_ip} #{prettify(size).rjust(10)}"
    end
  end

  def prettify(size)
    return size.to_s + 'B' if size < 1000
    (size / KILOBYTE).round(1).to_s + 'K'
  end

  def print_filesystem_changes
    changes_file = File.join(@evidence_path, BuildInspector::FILESYSTEM_CHANGES_FILE)
    lines = IO.readlines(changes_file)

    # Skip these lines; they are meaningless.
    lines -= [
      "changed: home/vagrant\n",
      "No changes found.  Directory matches archive data.\n",
    ]

    return if lines.empty?

    puts Printer.yellowify('File system changes:')
    lines.each { |line| puts line }
  end

  def print_running_processes
    procs_before_file = File.join(@evidence_path, BuildInspector::PROCESSES_BEFORE_FILE)
    procs_after_file = File.join(@evidence_path, BuildInspector::PROCESSES_AFTER_FILE)

    procs_before = File.readlines(procs_before_file)
    procs_after = File.readlines(procs_after_file)
    new_procs = procs_after - procs_before
    return if new_procs.empty?

    puts Printer.yellowify('New processes running after the build:')
    new_procs.flatten.each do |proc|
      puts "  - #{proc}"
    end
  end
end
