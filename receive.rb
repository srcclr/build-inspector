
require 'bunny'
require 'aws-sdk'
require 'json'

conn = Bunny.new
conn.start

ch = conn.create_channel
q = ch.queue('build-inspector-repos')

puts " [*] Waiting for messages in #{q.name}. To exit press CTRL+C"
q.subscribe(:block => true) do |delivery_info, properties, body|
  puts " [x] Received #{body}"

  # cancel the consumer to exit
  # delivery_info.consumer.cancel

  payload = JSON.parse(body)

  `./inspector --#{payload[:type]} --package=#{payload[:library]} test-repos/TotallyLegitApp`

  file = File.new(`ls *.zip`)
  upload(file)
  File.delete(file)
end

def upload(file)
  s3 = Aws::S3::Resource.new(region:'us-west-2')
  obj = s3.bucket('build-inspector').object(File.basename(file))
  obj.upload_file(File.absolute_path(file))
end