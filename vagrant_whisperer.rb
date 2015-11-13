require './utils'

class VagrantWhisperer

  EVIDENCE_DIR = '/evidence'
  BACKUP_DIR = '/backup'
  TMP_DIR = '/tmp'

  def initialize
    @ssh_opts = parse_ssh_config(`vagrant ssh-config`)
  end

  def run(commands)
    file_path = 'tmp_runCommands.sh'
    dest_path = File.join TMP_DIR, file_path
    commands.unshift "#!/bin/bash"
    commands << "rm #{dest_path}"

    File.open(file_path, 'w') { |f| commands.each { |cmd| f.write "#{cmd}\n" } }
    sendFile(file_path, dest_path)
    File.delete(file_path)

    ssh_exec "chmod +x #{dest_path}"

    # Stream output as we get it
    $stdout.sync = true
    command = "ssh #{ssh_args} #{dest_path}"
    Utils.exec_puts command
  end

  def run_and_get(commands)
    file_path = 'tmp_runCommands.sh'
    dest_path = File.join TMP_DIR, file_path
    commands.unshift "#!/bin/bash"
    commands << "rm #{dest_path}"

    File.open(file_path, 'w') { |f| commands.each { |cmd| f.write "#{cmd}\n" } }
    sendFile(file_path, dest_path)
    File.delete(file_path)

    ssh_exec "chmod +x #{dest_path}"

    # Stream output as we get it
    $stdout.sync = true
    command = "ssh #{ssh_args} #{dest_path}"
    IO.popen(command).read
  end

  def collectEvidence(into = "#{Utils.timestamp}-evidence.zip")
    evidence_zip_path = "#{home}/#{into}"

    zip(EVIDENCE_DIR, into = evidence_zip_path)

    getFile(evidence_zip_path)
  end

  def zip(dir, into = dir)
    zip_file = into
    zip_file = "#{zip_file}.zip" if !zip_file.end_with? '.zip'
    run(["zip -r #{zip_file} #{dir}"])
  end

  def sendFile(local_path, remote_path)
    cmd = "scp #{ssh_opts_str} #{local_path} #{@ssh_opts['User']}@#{@ssh_opts['HostName']}:#{remote_path}"
    `#{cmd}`
  end

  def getFile(remote_path, local_path = '.')
    cmd = "scp #{ssh_opts_str} #{@ssh_opts['User']}@#{@ssh_opts['HostName']}:#{remote_path} #{local_path}"
    `#{cmd}`
  end

  def ip_address
    @ip_address ||= ssh_exec("ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\\/.*$//'").strip.split.first
    @ip_address
  end

  def home
    @home ||= run_and_get(['echo $HOME']).strip
    @home
  end

  private

  def ssh_exec(command)
    `ssh #{ssh_args} "#{command}"`
  end

  def ssh_args
    "#{ssh_opts_str} -t #{@ssh_opts['User']}@#{@ssh_opts['HostName']}"
  end

  def ssh_opts_str
    @ssh_opts.map { |k,v| "-o #{k}=#{v}"}.join(' ')
  end

  def parse_ssh_config(config)
    ssh_opts = {}
    config.lines.map(&:strip).each do |e|
      next if e.empty?
      k, v = e.split(/\s+/)
      ssh_opts[k] = v
    end

    # Silence ssh logging
    ssh_opts['LogLevel'] = 'QUIET'

    # Remove Host directive as it doesn't work on some systems
    ssh_opts.tap { |opts| opts.delete('Host') }
  end
end
