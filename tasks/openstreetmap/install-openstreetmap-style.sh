#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

# There needs to be at least 150GB free disk space in the cache dir
IMPORT_CACHE_DIR=$ALVAR_MAP_SERVER_DATA_DIR/.importcache

cd $HOME

echo -e "\nUsing osm2pgsql (openstreetmap-carto style) to import data ..\n"
sudo add-apt-repository -y ppa:kakrueger/openstreetmap
sudo apt-get update
sudo apt-get --no-install-recommends install -y osm2pgsql osmctools

# Temporarily allow overcommit setting to allow faster osm2pgsql imports
sysctl -w vm.overcommit_memory=1

mkdir -p $HOME/osm
cd $HOME/osm
git clone https://github.com/gravitystorm/openstreetmap-carto.git openstreetmap-carto

cd openstreetmap-carto

osm2pgsql -U osm -d osm --create --slim \
  --flat-nodes $ALVAR_MAP_SERVER_DATA_DIR/osm2pgsql_flat_nodes.bin \
  --cache 14000 --number-processes 8 --hstore \
  --style openstreetmap-carto.style --multi-geometry \
  $ALVAR_MAP_SERVER_DATA_DIR/planet-latest.osm.pbf

psql -f indexes.sql postgres://osm:osm@localhost:5432/osm
./get-shapefiles.sh

source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/openstreetmap/download-fonts.sh


