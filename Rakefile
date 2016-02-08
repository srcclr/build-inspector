require './utils'

namespace :v do
  desc 'Restores the previously committed machine state'
  task :rollback do
    Utils.exec_puts 'vagrant sandbox rollback'
  end

  desc "Commits the machine's state. Future rollbacks will go to this state"
  task :commit do
    Utils.exec_puts 'vagrant sandbox commit'
  end

  task :halt do
    Utils.exec_puts 'vagrant halt'
  end

  task :up do
    Utils.exec_puts 'vagrant up'
  end

  task :destroy do
    Utils.exec_puts 'vagrant destroy -f'
  end

  desc 'Equivalent to a `vagrant destroy && vagrant up`'
  task rebuild: [:destroy, :up]

  desc 'Equivalent to a `vagrant halt && vagrant up`'
  task :reload do
    Utils.exec_puts 'vagrant reload'
  end
end
