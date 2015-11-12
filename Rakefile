namespace :v do
  desc 'Restores the previously committed machine state'
  task :rollback do
    exec_puts 'vagrant sandbox rollback'
  end

  desc "Commits the machine's state. Future rollbacks will go to this state"
  task :commit do
    exec_puts 'vagrant sandbox commit'
  end

  task :halt do
    exec_puts 'vagrant halt'
  end

  task :up do
    exec_puts 'vagrant up'
  end

  task :destroy do
    exec_puts 'vagrant destroy -f'
  end

  desc 'Equivalent to a `vagrant destroy && vagrant up`'
  task rebuild: [:destroy, :up]

  desc 'Equivalent to a `vagrant halt && vagrant up`'
  task :reload do
    exec_puts 'vagrant reload'
  end

  # Because "puts `cmd`" doesn't stream the output as it appears
  def exec_puts(command)
    IO.popen(command) do |f|
      puts f.gets until f.eof?
    end
  end
end
