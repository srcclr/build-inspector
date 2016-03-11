require 'rake'
require 'optparse'
require_relative 'lib/printer'

namespace :vagrant do
  desc 'Restores the previously committed machine state'
  task :rollback do
    Printer.exec_puts('vagrant sandbox rollback')
  end

  desc "Commits the machine's state. Future rollbacks will go to this state"
  task :commit do
    Printer.exec_puts('vagrant sandbox commit')
  end

  desc "Gracefully stop Vagrant"
  task :halt do
    Printer.exec_puts('vagrant halt')
  end

  desc "Start Vagrant"
  task :up do
    Printer.exec_puts('vagrant up')
  end

  desc "Upgrade Vagrant image"
  task :update do
    Printer.exec_puts('vagrant box update')
  end

  desc "Destroy Vagrant image"
  task :destroy do
    Printer.exec_puts('vagrant destroy -f')
  end

  desc 'Equivalent to a `vagrant destroy && vagrant up`'
  task rebuild: [:destroy, :up]

  desc 'Equivalent to a `vagrant halt && vagrant up`'
  task :reload do
    Printer.exec_puts('vagrant reload')
  end

  desc 'Check environment to determine if build-inspector should work'
  task :test do
    vagrant_path = `which vagrant`
    if vagrant_path == '' || vagrant_path == 'vagrant not found'
      puts "Vagrant installed:\t\tNO"
      return
    else
      puts "Vagrant installed:\t\tyes - path=#{vagrant_path}"
    end

    plugin_str = `vagrant plugin list`
    indx = plugin_str.index('sahara (')
    if indx
      start_offset = indx + 'sahara ('.length
      end_offset = plugin_str.index(')', start_offset) - 1
      sandbox_version = plugin_str[start_offset..end_offset]
      puts "Sandbox plugin installed:\tyes - version=#{sandbox_version}"
    else
      puts "Sandbox plugin installed:\tNO"
    end

    status_str = `vagrant status`
    status_line = status_str.split("\n").select { |e| e.start_with?('default') }.first
    status = status_line.split(/\s+/)[1]
    if status == 'not created'
      puts "Box provisioned:\t\tNO"
    else
      puts "Box provisioned:\t\tyes - status=#{status}"
    end
  end
end
