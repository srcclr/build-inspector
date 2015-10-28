namespace :v do
  desc 'Restores the previously committed machine state'
  task :rollback do
    `vagrant sandbox rollback`
  end

  desc "Commits the machine's state. Future rollbacks will go to this state"
  task :commit do
    `vagrant sandbox commit`
  end

  task :halt do
    `vagrant halt`
  end

  task :up do
    `vagrant up`
  end

  desc 'Equivalent to a `vagrant halt && vagrant up`'
  task :reload do
    `vagrant reload`
  end
end
