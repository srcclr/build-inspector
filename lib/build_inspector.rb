require_relative 'vagrant_whisperer'
require_relative 'utils'

class BuildInspector
  EVIDENCE_PATH = '/evidence'
  BACKUP_PATH = '/backup'
  REPO_PATH = '$HOME/repo'

  def initialize(whisperer:, repo_url:, commands:, evidence_files: '', rollback: true, verbose: false)
    @whisperer = whisperer
    @repo_url = repo_url
    @commands = commands
    @evidence_files = evidence_files
    @rollback = rollback
    @verbose = verbose
  end

  def inspect
    @whisperer.run(message: "Cloning #{@repo_url} ...") do |commands|
      commands << "git clone #{@repo_url} #{REPO_PATH}"
    end

    filelist = @evidence_files.gsub(/\$HOME/, @whisperer.home)
    local_list = Tempfile.new('evidence-files')
    local_list.write(filelist)
    local_list.rewind
    rdiff_filelist_path = File.join(VagrantWhisperer::TMP_PATH, 'evidence-files.txt')
    @whisperer.send_file(local_list.path, rdiff_filelist_path)
    local_list.close
    local_list.unlink

    @whisperer.run(message: 'Preparing file system snapshot ...') do |commands|
      target_path = '/'
      commands << "sudo rdiff-backup --include-filelist #{rdiff_filelist_path} #{target_path} #{BACKUP_PATH}"
    end

    @whisperer.run(message: 'Starting network monitoring ...') do |commands|
      commands << "sudo tcpdump -w #{EVIDENCE_PATH}/traffic.pcap -i eth0 > /dev/null 2>&1 &disown"
      commands << "ps --sort=lstart -eott,cmd > #{EVIDENCE_PATH}/ps-before.txt"
    end

    @whisperer.run(message: 'Starting build ...') do |commands|
      commands << "cd #{REPO_PATH}"

      commands.concat([@commands]).flatten! # config.script may be a list

      commands << Utils.yell('Done. Your build exited with $?.')
    end

    @whisperer.run(message: 'Cleaning up ...') do |commands|
      commands << 'sudo pkill tcpdump'
      commands << "ps --sort=lstart -eott,cmd > #{EVIDENCE_PATH}/ps-after.txt"
    end

    @whisperer.run(message: 'Generating file system changes ...') do |commands|
      get_current_mirror = "`sudo rdiff-backup --list-increments #{BACKUP_PATH} |  awk -F\": \" '$1 == \"Current mirror\" {print $2}'`"
      commands << "sudo rdiff-backup --include-filelist #{rdiff_filelist_path} --compare-at-time \"#{get_current_mirror}\" / #{BACKUP_PATH} > #{EVIDENCE_PATH}/fs-diff.txt"
      # TODO: do this locally rather than remotely
      commands << %Q~ruby -e 'IO.readlines("#{EVIDENCE_PATH}/fs-diff.txt").each { |e| puts e; o,f = e.strip.split(": "); puts `diff -u #{BACKUP_PATH}/\#{f} /\#{f} ` if o.eql?("changed") && File.exists?("/"+f) && !File.directory?("/"+f)}' > #{EVIDENCE_PATH}/fs-diff-with-changes.txt~
    end
  end
end
