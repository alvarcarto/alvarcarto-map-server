#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y unzip wget

echo -e "Downloading PBF data ..\n"
cd $ALVAR_MAP_SERVER_DATA_DIR

if [ "$ALVAR_ENV" = "qa" ] || [ "$ALVAR_ENV" = "docker" ]; then
    # Example alternatives:
    # PBF_URL=http://download.geofabrik.de/europe/finland-latest.osm.pbf
    # PBF_URL=http://download.geofabrik.de/europe-latest.osm.pbf
    # PBF_URL=http://download.geofabrik.de/europe/spain-latest.osm.pbf

    PBF_URL=http://download.geofabrik.de/europe/finland-latest.osm.pbf
else
    # Use another mirror to download planet PBF faster
    # https://wiki.openstreetmap.org/wiki/Planet.osm#Downloading
    #PBF_URL=https://ftp.fau.de/osm-planet/pbf/planet-latest.osm.pbf
    PBF_URL=http://download.geofabrik.de/europe/finland-latest.osm.pbf

    # Original:
    #PBF_URL=http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf
fi

for i in {1..5}; do wget "$PBF_URL" -O import-data.osm.pbf && break || sleep 15; done
