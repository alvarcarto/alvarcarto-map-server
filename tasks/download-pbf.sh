#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y unzip

echo -e "Downloading PBF data ..\n"
cd $ALVAR_MAP_SERVER_DATA_DIR

if [ "$ALVAR_ENV" = "qa" ]; then
    PBF_URL=http://download.geofabrik.de/europe/spain-latest.osm.pbf
else
    PBF_URL=http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf
fi

# PBF_URL=http://download.geofabrik.de/europe/finland-latest.osm.pbf
# PBF_URL=http://download.geofabrik.de/europe-latest.osm.pbf
# PBF_URL=http://download.geofabrik.de/europe/spain-latest.osm.pbf
wget "$PBF_URL" -O import-data.osm.pbf
