#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

# There needs to be at least 150GB free disk space in the cache dir
IMPORT_CACHE_DIR=$ALVAR_MAP_SERVER_DATA_DIR/.importcache

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/lyrk/download-fonts.sh
cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
source tasks/lyrk/download-osm-data.sh

cd $HOME

echo -e "\nUsing imposm (lyrk style) to import data .. \n"

# We are using the imposm3 mapping file from this style
git clone https://github.com/lyrk/lyrk-mapstyle.git lyrk-mapstyle-master

wget https://imposm.org/static/rel/imposm3-0.2.0dev-20160615-d495ca4-linux-x86-64.tar.gz
tar xzvvf imposm3-0.2.0dev-20160615-d495ca4-linux-x86-64.tar.gz
cd imposm3-0.2.0dev-20160615-d495ca4-linux-x86-64

mkdir -p $IMPORT_CACHE_DIR
echo -e "\n\nImporting entire planet data to Postgis.. This took 63h34m the last time ! \n\n"
./imposm3 import \
    -mapping $HOME/lyrk-mapstyle-master/imposm/mapping.json \
    -read $ALVAR_MAP_SERVER_DATA_DIR/import-data.osm.pbf \
    -write -connection postgis://osm:osm@localhost/osm \
    -optimize -deployproduction \
    -cachedir $IMPORT_CACHE_DIR
