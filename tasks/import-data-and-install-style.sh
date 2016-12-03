#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

if [ "$MAPNIK_STYLE" = "openstreetmap" ]; then
    echo -e "Installing openstreetmap style.. "
    source tasks/openstreetmap/install-openstreetmap-style.sh
elif [ "$MAPNIK_STYLE" = "osm-bright" ]; then
    echo -e "Installing osm-bright style.. "
    source tasks/osm-bright/install-osm-bright-style.sh
else
    echo -e "Installing lyrk style.. "
    source tasks/lyrk/install-lyrk-style.sh
fi
