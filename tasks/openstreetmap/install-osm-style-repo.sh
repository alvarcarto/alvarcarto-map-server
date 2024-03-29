#!/bin/bash

set -e
set -x

[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

echo -e "Installing openstreetmap style.. "

sudo apt-get update
sudo apt-get install -y osmctools git python3-distutils python python3 mapnik-utils

mkdir -p $ALVAR_MAP_SERVER_INSTALL_DIR/osm
cd $ALVAR_MAP_SERVER_INSTALL_DIR/osm
git clone https://github.com/gravitystorm/openstreetmap-carto.git openstreetmap-carto
cd openstreetmap-carto
git checkout 6c89079aa15a3999142fd7e3fc9b89a12ca5249a

# Get shapefiles. Retry if the downloading fails for some reason
for i in {1..5}; do ./scripts/get-shapefiles.py && break || sleep 15; done

