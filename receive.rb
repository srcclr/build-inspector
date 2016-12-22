
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

  run_inspector({rollback: true,
    config: "configs/#{payload['type']}.yml",
    branch: 'master',
    only_process: nil,
    is_url: false,
    verbose: false,
    package: payload['library']
  }, 'test-repos/TotallyLegitApp')

  destroy_evidence
  puts " [x] Finished processing #{body}"
end
