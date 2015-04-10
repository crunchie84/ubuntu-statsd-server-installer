#!/bin/sh

sudo apt-get update
sudo apt-get install -q -y --force-yes --assume-yes graphite-web graphite-carbon

cat >> /etc/graphite/local_settings.py <<EOF
TIME_ZONE = 'Europe/Amsterdam'
SECRET_KEY = 'NOT UNSAFE KEY REALLY TRUST ME'

LOG_RENDERING_PERFORMANCE = True
LOG_CACHE_PERFORMANCE = True
LOG_METRIC_ACCESS = True

CONF_DIR = '/etc/graphite'
STORAGE_DIR = '/var/lib/graphite/whisper'
CONTENT_DIR = '/usr/share/graphite-web/static'
WHISPER_DIR = '/var/lib/graphite/whisper'
#RRD_DIR = '/opt/graphite/storage/rrd'
#DATA_DIRS = [WHISPER_DIR, RRD_DIR] # Default: set from the above variables
LOG_DIR = '/var/log/graphite'
INDEX_FILE = '/var/lib/graphite/search_index'  # Search index file


DATABASES = {
    'default': {
        'NAME': '/var/lib/graphite/graphite.db',
        'ENGINE': 'django.db.backends.sqlite3',
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': ''
    }
}

EOF

sudo graphite-manage syncdb

cat >> /tmp/graphite-carbon <<EOF
# Change to true, to enable carbon-cache on boot
CARBON_CACHE_ENABLED=true
EOF
sudo cp /tmp/graphite-carbon /etc/default/graphite-carbon
