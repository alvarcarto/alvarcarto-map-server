#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

echo -e "\nUsing osm2pgsql (osm-bright style) to import data ..\n"

source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/openstreetmap/install-osm2pgsql.sh
sudo apt-get update
sudo apt-get install -y osmctools

# Temporarily allow overcommit setting to allow faster osm2pgsql imports
sudo sysctl -w vm.overcommit_memory=1

cd $HOME
git clone https://github.com/mapbox/osm-bright.git osm-bright
cd osm-bright

source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/osm-bright/download-osm-data.sh
cd $HOME/osm-bright
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/osm-bright/download-fonts.sh

export PGPASSWORD=osm
osm2pgsql -U osm -d osm -H localhost -P 5432 --create --slim \
  --create \
  --drop \
  --flat-nodes $ALVAR_MAP_SERVER_DATA_DIR/osm2pgsql_flat_nodes.bin \
  --cache 24000 --number-processes 2 --hstore \
  --disable-parallel-indexing \
  --multi-geometry \
  $ALVAR_MAP_SERVER_DATA_DIR/import-data.osm.pbf
