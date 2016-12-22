
require 'bunny'
require 'json'

conn = Bunny.new
conn.start
ch = conn.create_channel
q = ch.queue('build-inspector-repos')

payload = {
  type: 'npm',
  library: 'wasdk'
}

ch.default_exchange.publish(payload.to_json, :routing_key => q.name)

puts " [x] Sent '#{payload.to_json}'"

conn.close
