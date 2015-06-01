#!/bin/bash

# based on http://digitalronin.github.io/2014/04/29/installing-graphite-on-ubuntu-1404/
# run this script as superuser or it will fail

echo -e "\nINSTALLING graphite-web + carbon-cache + apache2 \n"
apt-get update
# setting debian_frontend to noninteractive prevents apt-get post install (whiptail) screens
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq --force-yes graphite-web
apt-get install -y -qq --force-yes graphite-carbon
apt-get install -y -qq --force-yes apache2
apt-get install -y -qq --force-yes libapache2-mod-wsgi

# make apache serve the graphite website
rm /etc/apache2/sites-enabled/000-default.conf
ln -s /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-enabled/

echo -e "\nCONFIGURING graphite + initializing database... \n"
#append secret key and timezone to /etc/graphite/local_settings.py
cat >> /etc/graphite/local_settings.py <<EOF
TIME_ZONE = 'Europe/Amsterdam'
SECRET_KEY = '#UZ$!wNKYGBv'
EOF

# init django db (--noinput for unattended install => http://stackoverflow.com/questions/23202805/manage-py-flag-to-force-unattended-command)
# NOTE: This is using the default sqlite3 database backend.
# This is not recommended for production servers, so you will want
# to change that (and probably a lot of other things) when you’re
# ready to move your graphite server into production
python /usr/lib/python2.7/dist-packages/graphite/manage.py syncdb --noinput

chmod 666 /var/lib/graphite/graphite.db
chmod 755 /usr/share/graphite-web/graphite.wsgi

# make carbon-cache restart automatically
cat >> /etc/default/graphite-carbon <<EOF
# Change to true, to enable carbon-cache on boot
CARBON_CACHE_ENABLED=true
EOF

# configure metrics retention policies on disk
rm /etc/carbon/storage-schemas.conf
cat >> /etc/carbon/storage-schemas.conf <<EOF
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.

# Carbon's internal metrics. This entry should match what is specified in
# CARBON_METRIC_PREFIX and CARBON_METRIC_INTERVAL settings
[carbon]
pattern = ^carbon\.
retentions = 60:90d

[stats]
pattern = .*
retentions = 10s:8d,1m:31d,10m:1y,1h:5y

EOF

# define that we want to aggegrate counters with a sum field when
# aggregating to lower-precision data retention
cat >> /etc/carbon/storage-aggregation.conf <<EOF

[counters]
pattern = stats.counts.*
xFilesFactor = 0.0
aggregationMethod = sum

EOF

#
# Install STATSD collector service
#
echo -e "\nINSTALLING STATSD... \n"
apt-get install -y -qq --force-yes nodejs
apt-get install -y -qq --force-yes git
git clone git://github.com/etsy/statsd.git /opt/statsd
cat >> /opt/statsd/localConfig.js << EOF
{
  graphitePort: 2003,
  graphiteHost: "127.0.0.1",
  port: 8125,
  mgmt_port: 8126,
  percentThreshold: [90,95,99],
  legacyNamespace: false
}
EOF

#
# Make the service be automatically started and monitored
#
echo -e "\nINSTALLING AND CONFIGURING MONIT + UPSTART... \n"
apt-get install -y -qq --force-yes upstart monit

#create startup script for statsd
cat >> /etc/init/statsd.conf <<EOF
#!upstart
description "Statsd node.js server"
author      "statsd install gist"

start on startup
stop on shutdown

script
    export HOME="/root"

    echo $$ > /var/run/statsd.pid
    exec sudo -u www-data /usr/bin/nodejs /opt/statsd/stats.js /opt/statsd/localConfig.js  >> /var/log/statsd.log 2> /var/log/statsd.error.log
end script

pre-start script
    # Date format same as (new Date()).toISOString() for consistency
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/statsd.log
end script

pre-stop script
    rm /var/run/statsd.pid
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/statsd.log
end script
EOF

#configure monit to use our upstart script
cat >> /etc/monit/conf.d/statsd <<EOF
#!monit
set logfile /var/log/monit.log

check process nodejs with pidfile "/var/run/statsd.pid"
    start program = "/sbin/start statsd"
    stop program  = "/sbin/stop statsd"
EOF

#now start the graphite-web interface
service monit restart
service carbon-cache restart
service apache2 restart

echo -e "\nDONE..."
echo -e "The statsd service is listening on port 8125 UDP, graphite web is availabe on port 80"
echo -e "PLEASE NOTE: this is not a production worthy install!"
echo -e "Have fun..."
