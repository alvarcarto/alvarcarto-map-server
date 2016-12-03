#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y unzip

echo -e "Downloading shape data ..\n"

mkdir -p shp
cd shp

wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
unzip simplified-land-polygons-complete-3857.zip
cd simplified-land-polygons-complete-3857
shapeindex simplified_land_polygons.shp
cd ..

wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip
unzip land-polygons-split-3857.zip
cd land-polygons-split-3857
shapeindex land_polygons.shp
cd ..

# This was needed by OSM Bright, downloaded for just in case.
# The new Lyrk mapstyle doesn't directly use it
wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip
mkdir ne_10m_populated_places
mv ne_10m_populated_places.zip ne_10m_populated_places
cd ne_10m_populated_places
unzip ne_10m_populated_places.zip
shapeindex ne_10m_populated_places.shp
cd ..
