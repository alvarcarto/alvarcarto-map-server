#!/bin/bash

# Requirements before running:
#
# * Fresh Ubuntu 18.04
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
# /home/alvar should exist, but /home/alvar/data shouldn't. This script
# creates that directory.
# Path MUST NOT contain a trailing slash

export ALVAR_MAP_SERVER_INSTALL_DIR=${ALVAR_MAP_SERVER_INSTALL_DIR:-/home/alvar}
export ALVAR_MAP_SERVER_DATA_DIR=${ALVAR_MAP_SERVER_DATA_DIR:-/home/alvar/data}
export ALVAR_ENV=${ALVAR_ENV:-prod}

echo "ALVAR_MAP_SERVER_INSTALL_DIR=$ALVAR_MAP_SERVER_INSTALL_DIR"
echo "ALVAR_MAP_SERVER_DATA_DIR=$ALVAR_MAP_SERVER_DATA_DIR"
echo "ALVAR_ENV=$ALVAR_ENV"

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
source /etc/environment

sudo mkdir -p $ALVAR_MAP_SERVER_DATA_DIR
sudo chown $(whoami):$(whoami) $ALVAR_MAP_SERVER_DATA_DIR

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install git -y

export ALVAR_MAP_SERVER_REPOSITORY_DIR=$(pwd)

echo -e "Creating $ALVAR_MAP_SERVER_DATA_DIR/mapnik-styles dir .. "
mkdir -p $ALVAR_MAP_SERVER_DATA_DIR/mapnik-styles

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/install-node.sh

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/install-mapnik.sh

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/install-and-configure-postgres.sh

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/download-pbf.sh

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/openstreetmap/install-openstreetmap-style.sh

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/install-caddy.sh

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/install-alvar-repos.sh "$1"
