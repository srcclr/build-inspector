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
end
