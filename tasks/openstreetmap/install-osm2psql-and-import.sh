#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

echo -e "\nUsing osm2pgsql (openstreetmap-carto style) to import data ..\n"

sudo apt-get install -y make cmake g++ libboost-dev libboost-system-dev \
  libboost-filesystem-dev libexpat1-dev zlib1g-dev \
  libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 \
  liblua5.2-dev git

cd $HOME
git clone git://github.com/openstreetmap/osm2pgsql.git
cd osm2pgsql
mkdir build && cd build
cmake ..
JOBS=8 make
sudo make install


cd $HOME/osm/openstreetmap-carto

# Temporarily allow overcommit setting to allow faster osm2pgsql imports
sudo sysctl -w vm.overcommit_memory=1

# Set CPU scaling governor to perf mode:
# https://askubuntu.com/questions/20271/how-do-i-set-the-cpu-frequency-scaling-governor-for-all-cores-at-once
function setgov () {
  # Inside docker, the cpu frequence scaling files don't exist,
  # It is just optimisation so we default to continue if it fails
  echo "$1" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor || echo "Failed to set scaling governor to performance.. Continuing.."
}

setgov performance

export PGPASSWORD=osm
if [ "$ALVAR_ENV" = "qa" ] || [ "$ALVAR_ENV" = "docker" ]; then
    echo -e "Running qa osm2pgsql command .."
    osm2pgsql -U osm -d osm -H localhost -P 5432 --create --slim \
      --flat-nodes $ALVAR_MAP_SERVER_DATA_DIR/osm2pgsql_flat_nodes.bin \
      --cache 4096 --number-processes 1 --hstore \
      --disable-parallel-indexing \
      --style openstreetmap-carto.style --multi-geometry \
      $ALVAR_MAP_SERVER_DATA_DIR/import-data.osm.pbf
else
    echo -e "Running prod osm2pgsql command .."
    osm2pgsql -U osm -d osm -H localhost -P 5432 --create --slim \
      --flat-nodes $ALVAR_MAP_SERVER_DATA_DIR/osm2pgsql_flat_nodes.bin \
      --cache 16000 --number-processes 4 --hstore \
      --disable-parallel-indexing \
      --style openstreetmap-carto.style --multi-geometry \
      $ALVAR_MAP_SERVER_DATA_DIR/import-data.osm.pbf
fi

psql -f indexes.sql postgres://osm:osm@localhost:5432/osm

# Remove quite large files which are not needed after import
rm $ALVAR_MAP_SERVER_DATA_DIR/osm2pgsql_flat_nodes.bin
rm $ALVAR_MAP_SERVER_DATA_DIR/import-data.osm.pbf
