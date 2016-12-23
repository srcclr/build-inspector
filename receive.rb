
require 'bunny'
require 'aws-sdk'
require 'json'
require_relative 'inspector_lib'
require 'fileutils'

def upload(file)
  puts " [x] Uploading #{file}..."
  s3 = Aws::S3::Resource.new(region:'us-east-1')
  obj = s3.bucket('build-inspector').object(File.basename(file))
  obj.upload_file(file)
  puts " [x] Uploaded #{file}"
end

def destroy_evidence
  files = Dir['*.zip']
  files.each do |f|
    upload(f)
    File.delete(f)
  end
  files.map { |f| File.basename(f, '.*') }.each { |f| FileUtils.remove_dir(f) }
end

bunny_host = ENV['BUNNY_HOST'] || 'localhost'
bunny_port = ENV['BUNNY_PORT'] || 5672
bunny_user = ENV['BUNNY_USER'] || 'guest'
bunny_pass = ENV['BUNNY_PASS'] || 'guest'

conn = Bunny.new(host: bunny_host, port: bunny_port, user: bunny_user, password: bunny_pass)
conn.start

ch = conn.create_channel

# Ensure that workers only get one message at a time
n = 1;
ch.prefetch(n);

q = ch.queue('build-inspector-repos', durable: true)

puts " [*] Waiting for messages in #{q.name}. To exit press CTRL+C"
q.subscribe(:block => true, manual_ack: true) do |delivery_info, properties, body|
  puts " [x] Received #{body}"

  # cancel the consumer to exit
  # delivery_info.consumer.cancel

  payload = JSON.parse(body)

  run_inspector({rollback: true,
    config: "configs/#{payload['type']}.yml",
    branch: 'master',
    only_process: nil,
    is_url: false,
    verbose: false,
    package: payload['library'],
    package_manager: payload['type']
  })

  destroy_evidence
  ch.ack(delivery_info.delivery_tag)
  puts " [x] Finished processing #{body}"
end
