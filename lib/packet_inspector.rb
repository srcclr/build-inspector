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

require 'packetfu'
require 'resolv'

class PacketInspector
  include PacketFu

  DNS_PORT = 53
  HTTP_PORT = 80
  HTTPS_PORT = 443

  def initialize(pcap_file)
    @packets = PcapFile.read_packets(pcap_file)
  end

  def packets_from(src_ip)
    @packets.find_all do |packet|
      packet.respond_to?(:ip_src_readable) && packet.ip_src_readable == src_ip
    end
  end

  def udp_packets_with_dst_port(port)
    @packets.find_all do |packet|
      packet.respond_to?(:udp_dst) && packet.udp_dst == port
    end
  end

  def tcp_packets_with_dst_port(port)
    @packets.find_all do |packet|
      packet.respond_to?(:tcp_dst) && packet.tcp_dst == port
    end
  end

  def udp_packets_with_src_port(port)
    @packets.find_all do |packet|
      packet.respond_to?(:udp_src) && packet.udp_src == port
    end
  end

  def tcp_packets_with_src_port(port)
    @packets.find_all do |packet|
      packet.respond_to?(:tcp_src) && packet.tcp_src == port
    end
  end

  def http_requests
    tcp_packets_with_dst_port(HTTP_PORT).map { |packet| packet.ip_daddr }
  end

  def http_responses
    tcp_packets_with_src_port(HTTP_PORT).map { |packet| packet.ip_saddr }
  end

  def dns_requests
    decoded_requests = udp_packets_with_dst_port(DNS_PORT).map { |p| Resolv::DNS::Message.decode(p.payload) }

    decoded_requests.each_with_object({}) do |request, memo|
      name = request.question.first.first.to_s
      memo[name] ||= []
    end
  end

  # returns a mapping of names to its ip addresses
  def dns_responses
    decoded_responses = udp_packets_with_src_port(DNS_PORT).map { |p| Resolv::DNS::Message.decode(p.payload) }

    decoded_responses.each_with_object({}) do |response, memo|
      name = response.question.first.first.to_s
      memo[name] ||= []
      response.answer.each do |ans|
        case ans.last
        when Resolv::DNS::Resource::IN::CNAME
          memo[name] << ans.last.name
        when Resolv::DNS::Resource::IN::AAAA, Resolv::DNS::Resource::IN::A
          memo[name] << ans.last.address
        else
          puts ans.last
        end
      end
    end
  end
end
