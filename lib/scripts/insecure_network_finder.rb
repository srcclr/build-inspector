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

class InsecureNetworkFinder < BuildInspectorScript

  def run
    pcap_file = File.join(@evidence_path, @file_to_analyze)
    packet_inspector = PacketInspector.new(pcap_file)
    hosts_contacted_via_http = {}

    dns_responses = packet_inspector.dns_responses
    address_to_name = dns_responses.each_with_object({}) do |name_addresses, memo|
      name = name_addresses.first
      addresses = name_addresses.last
      addresses.each { |address| memo[address.to_s] = name }
    end

    packet_inspector.http_requests.each do |request, path|
      if address_to_name.key?(request)
        (hosts_contacted_via_http[address_to_name[request]] ||= []) << (path if !hosts_contacted_via_http[address_to_name[request]].include?(path))
      else
        (hosts_contacted_via_http[request] ||= []) << (path if !hosts_contacted_via_http[address_to_name[request]].include?(path))
      end
    end

    hosts_contacted_via_http.each do |host, addresses|
      hosts_contacted_via_http[host] = addresses.compact
    end

    if !hosts_contacted_via_http.empty?
      add_results(hosts_contacted_via_http)
      save_results
      true
    else
      false
    end
  end


  def version
    '1'
  end

  private

  def load_results
    if File.file?(InsecureNetworkFinder::results_file_name) and !File.zero?(InsecureNetworkFinder::results_file_name)
      File.open(InsecureNetworkFinder::results_file_name, 'r') do |f|
        @results = JSON.load(f)
      end
    else
      @results = {}
    end
  end

  def save_results
    File.open(InsecureNetworkFinder::results_file_name, 'w+') do |f|
      f.write(JSON.pretty_generate(@results))
    end
  end

  def analysis_file_name
    'traffic.pcap'
  end

  def self.template_file_name
    'insecure_network_finder_template.html.erb'
  end

  def self.results_file_name
    'insecure_network_finder_results.json'
  end

end

