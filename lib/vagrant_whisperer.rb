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

class VagrantWhisperer
  TMP_PATH = '/tmp'.freeze
  TMP_CMDS = "#{TMP_PATH}/vagrantCommands.sh".freeze

  def initialize(verbose: false)
    @verbose = verbose
    @ssh_opts = parse_ssh_config(`vagrant ssh-config`)
  end

  def run(message: nil, stream: false)
    return unless block_given?
    puts Printer.yellowify(message) if message
    commands = []
    yield commands

    tf = Tempfile.new('inspector-commands')
    tf.write("#!/bin/bash\n")
    commands.each { |cmd| tf.write("#{cmd}\n") }
    tf.write("rm #{TMP_CMDS}")
    tf.rewind

    send_file(tf.path, TMP_CMDS)
    tf.close
    tf.unlink

    ssh_exec("bash -l #{TMP_CMDS}", stream: stream)
  end

  def up
    Printer.exec_puts 'vagrant up'
  end

  def snapshot
    Printer.exec_puts 'vagrant sandbox on'
  end

  def rollback
    puts Printer.yellowify('Rolling back virtual machine state ...')
    Printer.exec_puts 'vagrant sandbox rollback'
    ensure_ready
  end

  def ensure_ready
    attempts = 0
    while ssh_exec('echo ready', stream: true).strip != 'ready' do
      attempts += 1
      if attempts < 5 and attempts >= 0
        puts "VM is not yet ready; waiting..."
        sleep(120)
      else
        puts "VM failed. Exiting"
        exit
      end
    end
  end

  def send_file(local_path, remote_path)
    scp_cmd = File.directory?(local_path) ? 'scp -r' : 'scp'
    cmd = "#{scp_cmd} #{ssh_opts_str} #{local_path} #{@ssh_opts['User']}@#{@ssh_opts['HostName']}:#{remote_path}"
    puts "#{cmd}" if @verbose
    `#{cmd}`
  end

  def get_file(remote_path, local_path = '.')
    scp_cmd = File.directory?(local_path) ? 'scp -r' : 'scp'
    cmd = "#{scp_cmd} #{ssh_opts_str} #{@ssh_opts['User']}@#{@ssh_opts['HostName']}:#{remote_path} #{local_path}"
    puts "#{cmd}" if @verbose
    `#{cmd}`
  end

  def ip_address
    cmd = "ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\\/.*$//'"
    @ip_address ||= run(stream: true) { |c| c << cmd }.rstrip
  end

  def home
    @home ||= run(stream: true) { |c| c << 'echo $HOME' }.rstrip
  end

  private

  def ssh_exec(command, stream: false)
    full_cmd = "ssh #{ssh_args} \"#{command}\""
    puts full_cmd if @verbose
    if stream
      $stdout.sync = true
      IO.popen(full_cmd).read
    else
      Printer.exec_puts(full_cmd)
    end
  end

  def ssh_args
    "#{ssh_opts_str} -t #{@ssh_opts['User']}@#{@ssh_opts['HostName']}"
  end

  def ssh_opts_str
    @ssh_opts.map { |k, v| "-o #{k}=#{v}" } * ' '
  end

  def parse_ssh_config(config)
    ssh_opts = {}
    config.lines.map(&:strip).each do |e|
      next if e.empty?
      k, v = e.split(/\s+/, 2)
      ssh_opts[k] = v
    end

    # Silence ssh logging
    ssh_opts['LogLevel'] = 'QUIET'

    # Multiplex for faster ssh connections
    ssh_opts['ControlPath']    = '~/.ssh/%r@%h:%p'
    ssh_opts['ControlMaster']  = 'auto'
    ssh_opts['ControlPersist'] = '10m'

    # Remove Host directive as it doesn't work on some systems
    ssh_opts.tap { |opts| opts.delete('Host') }
  end
end
