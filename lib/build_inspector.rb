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

require_relative 'printer'
require_relative 'vagrant_whisperer'

class BuildInspector
  EVIDENCE_PATH = '/evidence'.freeze
  BACKUP_PATH = '/backup'.freeze
  REPO_PATH = '/home/vagrant/repo'.freeze
  RDIFF_TARGET = '/'.freeze

  PCAP_FILE = 'traffic.pcap'.freeze
  FILESYSTEM_DIFF_FILE = 'filesystem-diff.txt'.freeze
  FILESYSTEM_CHANGES_FILE ='filesystem-changes.txt'.freeze
  DIFF_RUBY = %Q~IO.readlines("#{EVIDENCE_PATH}/#{FILESYSTEM_DIFF_FILE}").each { |e| puts e; o,f = e.strip.split(": "); puts `diff -u #{BACKUP_PATH}/\#{f} /\#{f}` if o.eql?("changed") && File.exists?("/"+f) && !File.directory?("/"+f)}~.freeze
  FILESYSTEM_DIFF_CMD = "ruby -e '#{DIFF_RUBY}' > #{EVIDENCE_PATH}/#{FILESYSTEM_CHANGES_FILE}".freeze
  PROCESSES_BEFORE_FILE = 'ps-before.txt'.freeze
  PROCESSES_AFTER_FILE = 'ps-after.txt'.freeze
  PROCESSES_FILE = 'snoopy.log'.freeze

  def initialize(whisperer:, repo_path:, package:, is_url:, repo_branch: , commands:, evidence_files: '', verbose: false)
    @whisperer = whisperer
    @repo_path = repo_path
    @package = package
    @is_url = is_url
    @repo_branch = repo_branch
    @commands = Array(commands)
    @evidence_files = evidence_files
    @verbose = verbose
  end

  def inspect
    reset_network
    clone_repo
    snapshot_filesystem
    start_monitoring
    build
    stop_monitoring
    get_filesystem_changes
  end

  private

  def clone_repo
    return if @package

    if @is_url
      @whisperer.run(message: "Cloning #{@repo_path}:#{@repo_branch} ...") do |commands|
        branch = @repo_branch ? "--branch=#{@repo_branch}" : ''
        commands << "git clone --recursive --depth=50 #{branch} #{@repo_path} #{REPO_PATH}"
      end
    else
      @whisperer.run(message: "Copying #{@repo_path} to inspector ...") do |commands|
        @whisperer.send_file(@repo_path, REPO_PATH)
        if @repo_branch
          commands << "cd #{REPO_PATH}"
          commands << "git checkout #{@repo_branch}"
        end
      end
    end
  end

  def reset_network
    # If the host machine's IP address changes, this can confuse Vagrant
    # Resetting the network allows Vagrant to update network info
    @whisperer.run(stream: true) { |c| c << 'sudo ifdown eth0 && sudo ifup eth0' }
  end

  def snapshot_filesystem
    filelist = @evidence_files.gsub(/\$HOME/, @whisperer.home)
    local_list = Tempfile.new('evidence-files')
    local_list.write(filelist)
    local_list.rewind
    @whisperer.send_file(local_list.path, rdiff_filelist_path)
    local_list.close
    local_list.unlink

    @whisperer.run(message: 'Preparing file system snapshot (this may take a while) ...') do |commands|
      commands << "sudo rdiff-backup --include-filelist #{rdiff_filelist_path} #{RDIFF_TARGET} #{BACKUP_PATH}"
    end
  end

  def rdiff_filelist_path
    File.join(VagrantWhisperer::TMP_PATH, 'evidence-files.txt')
  end

  def start_monitoring
    @whisperer.run(message: 'Preparing network and process monitoring ...') do |commands|
      commands << "sudo tcpdump -w #{EVIDENCE_PATH}/traffic.pcap -i eth0 > /dev/null 2>&1 &disown"
      commands << "ps --sort=lstart -eott,cmd > #{EVIDENCE_PATH}/#{PROCESSES_BEFORE_FILE}"
      commands << "sleep 0.1 && truncate -s 0 /var/log/snoopy.log"
    end
  end

  def build
    @whisperer.run(message: 'Starting build ...') do |commands|
      commands << "cd #{REPO_PATH}"
      commands << "git submodule init"
      commands.concat(@commands)
      commands << Printer.yell('Done. Your build exited with $?.')
    end
  end

  def stop_monitoring
    @whisperer.run(message: 'Stopping network monitoring ...') do |commands|
      commands << 'sudo pkill tcpdump'
      commands << "ps --sort=lstart -eott,cmd > #{EVIDENCE_PATH}/#{PROCESSES_AFTER_FILE}"
    end
  end

  def get_filesystem_changes
    @whisperer.run(message: 'Generating file system changes ...') do |commands|
      get_current_mirror = "`sudo rdiff-backup --list-increments #{BACKUP_PATH} | awk -F\": \" '$1 == \"Current mirror\" {print $2}'`"
      commands << "sudo rdiff-backup --include-filelist #{rdiff_filelist_path} --compare-at-time \"#{get_current_mirror}\" #{RDIFF_TARGET} #{BACKUP_PATH} > #{EVIDENCE_PATH}/#{FILESYSTEM_DIFF_FILE}"

      # This MUST happen remotely, even though it's ugly, because it:
      # Uses diff, which may not be on host OS
      # May need to compare files against those in BACKUP_PATH
      commands << FILESYSTEM_DIFF_CMD
    end
  end
end
