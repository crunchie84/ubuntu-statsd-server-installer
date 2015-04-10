#!/bin/bash

#https://gist.github.com/bhang/2703599

# node.js using PPA (for statsd)
sudo apt-get update
sudo apt-get install python-software-properties
sudo apt-add-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install nodejs

# Install git to get statsd
sudo apt-get install git

# System level dependencies for Graphite
sudo apt-get install memcached python-dev python-pip sqlite3 libcairo2 \
 libcairo2-dev python-cairo pkg-config

# Get latest pip
sudo pip install --upgrade pip 

# Install carbon and graphite deps 
cat >> /tmp/graphite_reqs.txt << EOF
django==1.3
python-memcached
django-tagging==0.3.1
twisted
whisper==0.9.9
carbon==0.9.9
graphite-web==0.9.9
EOF

sudo pip install -r /tmp/graphite_reqs.txt

#
# Configure carbon
#
cd /opt/graphite/conf/
sudo cp carbon.conf.example carbon.conf

# Create storage schema and copy it over
# Using the sample as provided in the statsd README
# https://github.com/etsy/statsd#graphite-schema

cat >> /tmp/storage-schemas.conf << EOF
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.
#
#  [name]
#  pattern = regex
#  retentions = timePerPoint:timeToStore, timePerPoint:timeToStore, ...
[stats]
priority = 110
pattern = ^stats\..*
retentions = 10s:6h,1m:7d,10m:1y
EOF

sudo cp /tmp/storage-schemas.conf storage-schemas.conf

# Make sure log dir exists for webapp
sudo mkdir -p /opt/graphite/storage/log/webapp

# Copy over the local settings file and initialize database
cd /opt/graphite/webapp/graphite/
sudo cp local_settings.py.example local_settings.py
sudo python manage.py syncdb  # Follow the prompts, creating a superuser is optional

# statsd
cd /opt && sudo git clone git://github.com/etsy/statsd.git

# StatsD configuration
cat >> /tmp/localConfig.js << EOF
{
  graphitePort: 2003
, graphiteHost: "127.0.0.1"
, port: 8125
}
EOF

sudo cp /tmp/localConfig.js /opt/statsd/localConfig.js

#now run it
sudo /opt/graphite/bin/carbon-cache.py