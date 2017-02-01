=begin
Copyright 2016 SourceClear Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=end

require 'json'
require_relative 'build_inspector_script'
require_relative '../packet_inspector'

class NetworkActivityFinder < BuildInspectorScript

  def run
    pcap_file = File.join(@evidence_path, @file_to_analyze)
    packet_inspector = PacketInspector.new(pcap_file)

    # Whitelist the DNS' IP also; don't want it showing up
    dns_server = Resolv::DNS::Config.default_config_hash[:nameserver]
    whitelist = @host_whitelist
    whitelist += dns_server if dns_server

    dns_responses = packet_inspector.dns_responses
    address_to_name = dns_responses.each_with_object({}) do |name_addresses, memo|
      if !whitelist.include?(name_addresses.first)
        name = name_addresses.first
        addresses = name_addresses.last
        addresses.each { |address| memo[address.to_s] = name if !whitelist.include?(address.to_s) }
      end
    end

    add_results(address_to_name)
    save_results
    address_to_name and !address_to_name.empty?
  end


  def version
    '1'
  end

  private

  def load_results
    if File.file?(NetworkActivityFinder::results_file_name) and !File.zero?(NetworkActivityFinder::results_file_name)
      File.open(NetworkActivityFinder::results_file_name, 'r') do |f|
        @results = JSON.load(f)
      end
    else
      @results = {}
    end
  end

  def save_results
    File.open(NetworkActivityFinder::results_file_name, 'w+') do |f|
      f.write(JSON.pretty_generate(@results))
    end
  end

  def analysis_file_name
    'traffic.pcap'
  end

  def self.template_file_name
    'network_activity_finder_template.html.erb'
  end

  def self.results_file_name
    'network_activity_finder_results.json'
  end

end

