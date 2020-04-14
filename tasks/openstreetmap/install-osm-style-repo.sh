#!/bin/bash

set -e
set -x

[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

echo -e "Installing openstreetmap style.. "

sudo apt-get update
sudo apt-get install -y osmctools git python3-distutils python python3 mapnik-utils

mkdir -p $HOME/osm
cd $HOME/osm
git clone https://github.com/gravitystorm/openstreetmap-carto.git openstreetmap-carto
cd openstreetmap-carto
git checkout b761b0bfbce97332705698fbacea93dc007266f5

# Get shapefiles. Retry if the downloading fails for some reason
for i in {1..5}; do ./scripts/get-shapefiles.py && break || sleep 15; done

