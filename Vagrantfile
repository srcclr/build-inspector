# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu/trusty64'

  config.vm.box_check_update = false

  # Provisioning
  PROVISIONING_DIR = 'provisioning'
  sources = 'sources.list'
  sshd = 'sshd'
  snapshot_files = 'filesystem-snapshot.txt'
  config.vm.provision :file, source: File.join(PROVISIONING_DIR, sources), destination: sources
  config.vm.provision :file, source: File.join(PROVISIONING_DIR, sshd), destination: sshd
  config.vm.provision :file, source: File.join(PROVISIONING_DIR, snapshot_files), destination: snapshot_files
  config.vm.provision :shell, path: File.join(PROVISIONING_DIR, 'pre-package-bootstrap.sh'), keep_color: true
  config.vm.provision :shell, privileged: false, path: File.join(PROVISIONING_DIR, 'pre-package-bootstrap2.sh')
  config.vm.provision :shell, path: File.join(PROVISIONING_DIR, 'pre-package-bootstrap3.sh')
  config.vm.provision :shell, path: File.join(PROVISIONING_DIR, 'bootstrap.sh')

  # Security!
  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.provider 'virtualbox' do |vb|
    vb.customize ['modifyvm', :id, '--natdnsproxy1', 'off']
    vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'off']
    vb.memory = 3096
  end

  config.vm.provider :digital_ocean do |provider, override|
    override.ssh.private_key_path = ENV['PRIVATE_KEY_PATH'] || '~/.ssh/id_rsa'
    override.vm.box = 'digital_ocean'
    override.vm.box_url = "https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box"

    provider.name = 'inspector'
    provider.token = ENV['DIGITAL_OCEAN_TOKEN']
    provider.image = 'ubuntu-14-04-x64'
    provider.region = 'sgp1'
    provider.size = '512mb'
  end
end
