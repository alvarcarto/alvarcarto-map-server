#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

# There needs to be at least 150GB free disk space in the cache dir
IMPOSM_CACHE_DIR=$ALVAR_MAP_SERVER_DATA_DIR/.imposmcache

cd $HOME
wget https://imposm.org/static/rel/imposm3-0.2.0dev-20160615-d495ca4-linux-x86-64.tar.gz
tar xzvvf imposm3-0.2.0dev-20160615-d495ca4-linux-x86-64.tar.gz
cd imposm3-0.2.0dev-20160615-d495ca4-linux-x86-64

mkdir -p $IMPOSM_CACHE_DIR
echo -e "\n\nImporting entire planet data to Postgis.. This may take even 6 - 48 hours ! \n\n"
./imposm3 import -mapping mapping.json -read $ALVAR_MAP_SERVER_DATA_DIR/planet-latest.osm.pbf -write -connection postgis://osm:osm@localhost/osm -optimize -deployproduction -cachedir $IMPOSM_CACHE_DIR
