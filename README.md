# Statsd Ubuntu install scripts

This repository contains scripts to automatically install a Statsd + Graphite service upon an Ubuntu server. Easy for rapid deployment upon Azure, AWS or GAE.

# Vagrant
Supplied is an ubuntu 14.04 (etsy) Vagrant file with port forwarding

- Host 8080 → Vagrant 80 (TCP)
- Host 8125 → Vagrant 8125 (UDP)
- Host 8126 → Vagrant 8126 (TCP)

# How to install on your Ubuntu (VM)

- SSH into your fresh Ubuntu 14.04 machine
- download the script `wget https://raw.githubusercontent.com/crunchie84/ubuntu-statsd-server-installer/master/install-statsd-trusty-1404.sh`
- make it executable `chmod +x install-statsd-trusty-1404.sh`
- run it `sudo ./install-statsd-trusty-1404.sh`
- profit!

# License

GNU, see [LICENSE](LICENSE)
