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

require 'aws-sdk'
require 'fileutils'
require 'json'

class BuildInspectorS3

  def initialize(results_file, script_name)
    if credentials_not_found
      puts 'Please ensure the secrets AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY, are set in ENV.'
      exit -1
    end

    @uploader = Aws::S3::Resource.new(region: region_name)
    @client = Aws::S3::Client.new(region: region_name)
    @files = []
    @analyzed_evidence = load_results(results_file)
    @script_name = script_name
  end

  def upload(file)
    puts " [x] Uploading #{file}..."
    obj = @uploader.bucket(bucket_name).object(File.basename(file))
    obj.upload_file(file)
    puts " [x] Uploaded #{file}"
  end

  def get_evidences
    puts ' [x] Collecting new evidences...'
    @client.list_objects(bucket: bucket_name).each do |response|
      not_analyzed_evidence = response.contents.map { |object| object[:key] if !@analyzed_evidence.key?(evidence_folder(object[:key])) }.compact
      @files.concat not_analyzed_evidence
    end
    puts " [x] Collected #{@files.length} new evidence(s)."
    @files
  end

  def download(filename)
    puts " [x] Downloading #{filename}..."
    create_download_dir
    File.open(downloads_folder(filename), 'wb') do |file|
      reap = @client.get_object({ bucket: bucket_name, key: filename }, target: file)
    end
    puts " [x] Downloaded #{filename}"
    filename
  end

  def downloads_folder(filename='')
    File.expand_path("../../#{@script_name}/#{filename}", __FILE__)
  end


  private

  def evidence_folder(zipped_filename='')
    filename = zipped_filename.sub(/(.*)\.zip/, '\1')
    File.expand_path("../../#{@script_name}/#{filename}/evidence", __FILE__)
  end

  def load_results(file)
    return {} if !file

    if File.file?(file) and !File.zero?(file)
      File.open(file, 'r') do |f|
        @analyzed_evidence = JSON.load(f)
      end
    else
      @analyzed_evidence = {}
    end
  end

  def create_download_dir
    dirname = downloads_folder
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
  end

  def credentials_not_found
    return ((ENV['AWS_ACCESS_KEY_ID'] == nil) and (ENV['AWS_SECRET_ACCESS_KEY'] == nil))
  end

  def region_name
    ENV['AWS_REGION_NAME'] || 'us-east-1'
  end

  def bucket_name
    ENV['AWS_BUCKET_NAME'] || 'build-inspector'
  end

end
