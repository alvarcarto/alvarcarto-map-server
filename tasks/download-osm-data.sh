#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y unzip

echo -e "Downloading shape data ..\n"
cd $ALVAR_MAP_SERVER_DATA_DIR
wget http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf

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

wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_admin_0_boundary_lines_land.zip
mkdir ne_10m_admin_0_boundary_lines_land
mv ne_10m_admin_0_boundary_lines_land.zip ne_10m_admin_0_boundary_lines_land
cd ne_10m_admin_0_boundary_lines_land
unzip ne_10m_admin_0_boundary_lines_land.zip
shapeindex ne_10m_admin_0_boundary_lines_land.shp
cd ..

wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_countries.zip
mkdir ne_110m_admin_0_countries
mv ne_110m_admin_0_countries.zip ne_110m_admin_0_countries
cd ne_110m_admin_0_countries
unzip ne_110m_admin_0_countries.zip
shapeindex ne_110m_admin_0_countries.shp
cd ..
