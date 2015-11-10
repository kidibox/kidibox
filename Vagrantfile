# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANT_ROOT = File.dirname(File.expand_path(__FILE__))
file_to_disk = File.join(VAGRANT_ROOT, '.vagrant', 'filename.vdi')

Vagrant.configure("2") do |config|
  config.vm.box = 'terrywang/archlinux'
  config.vm.network :private_network, ip: '192.168.111.222'

  config.vm.provider 'virtualbox' do |vm|
    unless File.exist?(file_to_disk)
      vm.customize ['createhd', '--filename', file_to_disk, '--size', 500 * 1024]
    end

    vm.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
  end

  # Configure Ansible provisionner
  config.vm.provision :ansible do |ansible|
    ansible.playbook = 'ansible/site.yml'

    ansible.groups = {
      'vagrant' => 'default'
    }

    ansible.extra_vars = {
      'ansible_become' => 'yes',
      'ansible_python_interpreter' => '/usr/bin/python2',
      'volume_group_disk' => '/dev/sdb'
    }
  end
end
