# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty32"

  # graphite-web will be hosted on port 80 in the docker image
  # it will be available on port 8080 on your host machine
  # statsd will open port 8125 for udp and 8126 for maintenance
  # loopthrough
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 8125, host: 8125, protocol: 'udp'
  config.vm.network "forwarded_port", guest: 8126, host: 8126
end
