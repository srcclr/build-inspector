require_relative 'printer'
require_relative 'vagrant_whisperer'

class BuildInspector
  EVIDENCE_PATH = '/evidence'
  BACKUP_PATH = '/backup'
  REPO_PATH = '$HOME/repo'
  RDIFF_TARGET = '/'

  PCAP_FILE = 'traffic.pcap'
  FILESYSTEM_DIFF_FILE = 'filesystem-diff.txt'
  FILESYSTEM_CHANGES_FILE ='filesystem-changes.txt'
  PROCESSES_BEFORE_FILE = 'ps-before.txt'
  PROCESSES_AFTER_FILE = 'ps-after.txt'

  def initialize(whisperer:, repo_url:, commands:, evidence_files: '', verbose: false)
    @whisperer = whisperer
    @repo_url = repo_url
    @commands = commands
    @evidence_files = evidence_files
    @verbose = verbose
  end

  def inspect
    clone_repo
    snapshot_filesystem
    start_monitoring
    build
    stop_monitoring
    get_filesystem_changes
  end

  private

  def clone_repo
    @whisperer.run(message: "Cloning #{@repo_url} ...") do |commands|
      commands << "git clone #{@repo_url} #{REPO_PATH}"
    end
  end

  def snapshot_filesystem
    filelist = @evidence_files.gsub(/\$HOME/, @whisperer.home)
    local_list = Tempfile.new('evidence-files')
    local_list.write(filelist)
    local_list.rewind
    @whisperer.send_file(local_list.path, rdiff_filelist_path)
    local_list.close
    local_list.unlink

    @whisperer.run(message: 'Preparing file system snapshot ...') do |commands|
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
      commands << "truncate -s 0 /var/log/snoopy.log"
    end
  end

  def build
    @whisperer.run(message: 'Starting build ...') do |commands|
      commands << "cd #{REPO_PATH}"
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
      commands << %Q~ruby -e 'IO.readlines("#{EVIDENCE_PATH}/#{FILESYSTEM_DIFF_FILE}").each { |e| puts e; o,f = e.strip.split(": "); puts `diff -u #{BACKUP_PATH}/\#{f} /\#{f} ` if o.eql?("changed") && File.exists?("/"+f) && !File.directory?("/"+f)}' > #{EVIDENCE_PATH}/#{FILESYSTEM_CHANGES_FILE}~
    end
  end
end
