# StatsD Ubuntu install scripts

This repository contains scripts to automatically install a [Statsd](https://github.com/etsy/statsd/) + [Graphite](http://graphite.wikidot.com/) service upon an Ubuntu server. Easy for rapid deployment upon Azure, AWS or GAE.

# Vagrant
Supplied is an Ubuntu 14.04 ([trusty](http://releases.ubuntu.com/14.04/)) [Vagrant](https://www.vagrantup.com/) file with port forwarding to test this script in.

- Host 8080 → Vagrant 80 (TCP)
- Host 8125 → Vagrant 8125 (UDP)
- Host 8126 → Vagrant 8126 (TCP)

# How to install on your Ubuntu machine

- SSH into your fresh Ubuntu 14.04 machine
- download the script `wget https://raw.githubusercontent.com/crunchie84/ubuntu-statsd-server-installer/master/install-statsd-trusty-1404.sh`
- make it executable `chmod +x install-statsd-trusty-1404.sh`
- run it `sudo ./install-statsd-trusty-1404.sh`
- profit!

## Persist data to different location

Your whisper files are default stored in `/var/lib/graphite/whisper`. The sqllite django db + search_index are stored alongside them in `/var/lib/graphite` and only required for the web interface to function. To move your whisper files to a new data directory you will need to make the following changes:

- Create new data dir containing a `whisper` subfolder
- Make the new data dir accessible for graphite `chown _graphite._graphite /path/new-data-dir` and `chown _graphite._graphite /path/new-data-dir/whisper`
- Make the new data dir writeable `chmod 755 /path/new-data-dir` and `chmod 755 /path/new-data-dir/whisper`
- Update the `/etc/graphite/local_settings.py` config value `WHISPER_DIR` to point to `/path/new-data-dir/whisper`
- Update the `/etc/carbon/carbon.conf` config value 'STORAGE_DIR' and `LOCAL_DATA_DIR` so carbon-cache stores the files in the correct location (NOTE: storage_dir point to basedir, local_data_dir to the `/whisper` subfolder)
- Restart carbon-cache `service carbon-cache restart` to pick up the new value.
- Restart apache2 `service apache2 restart` to serve from new data dir.

# License

GNU, see [LICENSE](LICENSE)
