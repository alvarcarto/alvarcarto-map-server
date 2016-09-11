#!/bin/bash

# Requirements before running:
#
# * Fresh Ubuntu 16.04
# * Run this script as a sudo user, NOT root
# * $ALVAR_MAP_SERVER_DATA_DIR must have at least 450GB free disk space
# *

# Warning: running this will download ~40GB of data from internet,
#          over 400GB of disk space and a lot of server resources will be used

set -x
set -e

# Global install config

# Path to a data directory which will be used for storing planet .pbf data,
# Postgis data etc.
# This directory needs to be pointed to a volume which has at least 450GB free disk space
# /mnt/volume1 should exist, but /mnt/volume1/alvar shouldn't. This script
# creates that directory.
# Path MUST NOT contain a trailing slash
export ALVAR_MAP_SERVER_DATA_DIR=/mnt/volume1/alvar

if [ $(id -u) = 0 ]; then
    echo "This script must not be run as a root!"
    exit 1
fi

if [ -d "$ALVAR_MAP_SERVER_DATA_DIR" ]; then
    echo "$ALVAR_MAP_SERVER_DATA_DIR already exists! This is not expected."
    exit 1
fi

# Fix locale errors
sudo -H -u root bash -c 'echo "export LC_ALL=\"en_US.UTF-8\"" >> /etc/environment'

sudo mkdir -p $ALVAR_MAP_SERVER_DATA_DIR
sudo chown $(whoami):$(whoami) $ALVAR_MAP_SERVER_DATA_DIR

sudo apt-get update
sudo apt-get upgrade

source tasks/install-mapnik.sh
source tasks/install-and-configure-postgres.sh
source tasks/download-osm-data.sh
source tasks/import-osm-data.sh
