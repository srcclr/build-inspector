require 'fileutils'
require 'zip'
require_relative 'build_inspector'
require_relative 'vagrant_whisperer'

class EvidenceCollector
  def initialize(whisperer:, evidence_name:, verbose: false)
    @whisperer = whisperer
    @evidence_name = evidence_name
    @verbose = verbose
  end

  def collect
    zip_name = "#{@evidence_name}.zip"
    remote_zip_path = "#{@whisperer.home}/#{zip_name}"
    zip(BuildInspector::EVIDENCE_PATH, remote_zip_path)
    @whisperer.get_file(remote_zip_path)
    EvidenceCollector.unzip(zip_name, @evidence_name)

    # Call these after unzipping so target directory will exist
    copy_configuration
    get_snoopy_log
  end

  private

  def copy_configuration
    dest_file = File.join(@evidence_name, 'configuration.yml')
    FileUtils.copy_file('.inspect.yml', dest_file)
  end

  def get_snoopy_log
    @whisperer.run { |c| c << "sudo /var/log/snoopy.log #{BuildInspector::EVIDENCE_PATH}" }
  end

  def zip(target, zip_path)
    @whisperer.run { |c| c << "zip -r #{zip_path} #{target} 2>&1 > /dev/null" }
  end

  def self.unzip(zip_path, destination)
    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        path = File.join(destination, entry.name)
        FileUtils.mkdir_p(File.dirname(path))
        entry.extract(path) { true } # overwrite destination
      end
    end
  end
end
