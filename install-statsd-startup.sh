#!/bin/sh

sudo apt-get update -q
sudo apt-get install --assume-yes python-software-properties python-pip python-dev ruby-dev
sudo apt-add-repository -y ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install --assume-yes nodejs
sudo apt-get install --assume-yes git

# Install Graphite
#sudo apt-get install python-dev ruby-dev bundler build-essential libpcre3-dev

sudo pip install carbon
sudo pip install graphite-web

cat >> /tmp/graphite-carbon <<EOF
# Change to true, to enable carbon-cache on boot
CARBON_CACHE_ENABLED=true
EOF

sudo cp /tmp/graphite-carbon /etc/default/graphite-carbon

cat >> /tmp/carbon-storage-schemas.conf <<EOF
[stats]
priority = 110
pattern = .*
retentions = 10:2160,60:10080,600:262974
EOF

sudo sh -c 'cat /tmp/carbon-storage-schemas.conf >> /etc/carbon/storage-schemas.conf'

cat >> /tmp/carbon-storage-aggregation.conf <<EOF
[counters]
pattern = stats.counts.*
xFilesFactor = 0.0
aggregationMethod = sum
EOF

sudo sh -c 'cat /tmp/carbon-storage-aggregation.conf >> /etc/carbon/storage-aggregation.conf'

sudo /usr/bin/graphite-build-search-index
sudo /etc/init.d/carbon-cache start

### Install mysql for graphite - Change the pwd if you want

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
sudo apt-get install -yq mysql-server mysql-client
sudo mysql -h localhost -u root -proot -e "CREATE DATABASE graphite; grant usage on *.* to graphite@localhost identified by 'gr4phitepwd'; grant all privileges on graphite.* to graphite@localhost;"  
# above should automatically do the following:
# > CREATE  DATABASE graphite;
# > grant usage on *.* to graphite@localhost identified by 'gr4phitepwd';
# > grant all privileges on graphite.* to graphite@localhost;
# > exit

sudo apt-get install -yq yara python-mysqldb

cat <<EOF >> /etc/graphite/local_settings.py
DATABASES = {
    'default': {
        'NAME': 'graphite',
        'ENGINE': 'django.db.backends.mysql',
        'USER': 'graphite',
        'PASSWORD': 'gr4phitepwd',
        'HOST': 'localhost',
        'PORT': '3306'
    }
 }
EOF

### Add in connection string info
# sudo nano /etc/graphite/local_settings.py

# DATABASES = {
#    'default': {
#        'NAME': 'graphite',
#        'ENGINE': 'django.db.backends.mysql',
#        'USER': 'graphite',
#        'PASSWORD': 'gr4phitepwd',
#        'HOST': 'localhost',
#        'PORT': '3306'
#    }
# }

# Sync the graphite db
sudo graphite-manage syncdb

# Install apache
sudo apt-get install -yq apache2 libapache2-mod-wsgi
# Copy graphite configuration to apache
sudo cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-available/graphite-web.conf
# Enable graphite site with apache
sudo a2ensite graphite-web
sudo service apache2 restart


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

# Install upstart and monit to run statsd as a service
sudo apt-get install --assume-yes upstart monit

cat >> /tmp/statsd.conf <<EOF
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

sudo cp /tmp/statsd.conf /etc/init/statsd.conf

# Configure monit to monitor statsd service

cat >> /tmp/monit.conf <<EOF
#!monit
set logfile /var/log/monit.log

check process nodejs with pidfile "/var/run/statsd.pid"
    start program = "/sbin/start statsd"
    stop program  = "/sbin/stop statsd"
EOF

sudo cp /tmp/monit.conf /etc/monit/conf.d/statsd

# Restart monit
sudo /etc/init.d/monit restart


#######################################################
#### Update graphite with some missing functions

#sudo nano /usr/share/pyshared/graphite/render/functions.py
# Add to  /usr/share/pyshared/graphite/render/functions.py (Around the "def movingAverage("):
# 
#def historicalAverage(requestContext, seriesLists, points=7, offset=86400, highPassCount=1, lowPassCount=1):
#  historicalLists = []
#  for series in seriesLists:
#    hlist = []
#    for i in range(1,points+1):
#      tShift = str(offset * i) + "s"
#      shiftedSeries = timeShift(requestContext, [series], tShift)
#      hlist.append(shiftedSeries[0])
#    (hlist,start,end,step) = normalize([hlist])
#    values = (filterAvg(row, highPassCount, lowPassCount) for row in izip(*hlist) )
#    name = "historicalAverage(%s,%d,%d,%d,%d)" % (series.name, points, offset, highPassCount, lowPassCount)
#    return [TimeSeries(name,start,end,step,values)]
# 
#def filterAvg(row, highPassCount, lowPassCount):
#  vals = sorted(row)
#  if (highPassCount > 0):
#    del vals[:highPassCount]
#  if (lowPassCount > 0):
#    del vals[-lowPassCount:]
#  return safeDiv(safeSum(vals), safeLen(vals))
# 
#def fillValue(seriesList, placeholder=0):
#  for series in seriesList:
#    series.name = "fillValue(%s, %i)" % (series.name, placeholder)
#    for i,value in enumerate(series):
#      if value is None and i != 0:
#        value = placeholder
#      series[i] = value
#  return seriesList
  
  
# Search for "# Special functions" and add the following lines around the "'keepLastValue' : keepLastValue," line:
 
#  'historicalAverage' : historicalAverage,
#  'filterAvg' : filterAvg,
#  'fillValue' : fillValue,
  
  
#### Restart apache
sudo service apache2 restart