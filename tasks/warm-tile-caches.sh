#!/bin/bash

set -e
set -x


echo "Warming caches .. warning: this may take a very long time!"

npm install -g @alvarcarto/tilewarm
curl -O https://raw.githubusercontent.com/alvarcarto/tilewarm/master/geojson/world.geojson
curl -O https://raw.githubusercontent.com/alvarcarto/tilewarm/master/geojson/all-cities.geojson

# Iterate all styles (~12) in cartocss repo
# For each style we need to fetch 80k + 13k = ~100k tiles, this totals 1.2M tile requests
# If request takes 1000ms on average, this process takes 333h ~= 14d
for i in $(find "$ALVAR_MAP_SERVER_INSTALL_DIR/mapnik-styles/" -name '*.xml');
do
  style=$(basename "$i" .xml)

  if [ "$ALVAR_ENV" == "prod" ]; then
    # 1-8 zoom levels for whole world is 80k tiles
    echo "Warming caches (production) with world.geojson for style $style .."
    NODE_OPTIONS=--max_old_space_size=4096 tilewarm "http://localhost:8002/$style/{z}/{x}/{y}/tile.png" --input world.geojson --max-retries 20 --retry-base-timeout 1000 -c 'z < 7 ? 1 : 5' --zoom 1-8 --verbose

    # 10 zoom level for all cities is 13k tiles
    echo "Warming caches (production) with all-cities.geojson for style $style .."
    NODE_OPTIONS=--max_old_space_size=4096 tilewarm "http://localhost:8002/$style/{z}/{x}/{y}/tile.png" --input all-cities.geojson --max-retries 10 --retry-base-timeout 1000 -c 20 --zoom 10 --verbose
  else
    # 10 zoom level for all cities is 13k tiles
    echo "Warming caches (qa) with all-cities.geojson for style $style .."
    NODE_OPTIONS=--max_old_space_size=4096 tilewarm "http://localhost:8002/$style/{z}/{x}/{y}/tile.png" --input all-cities.geojson --max-retries 10 --retry-base-timeout 1000 -c 20 --zoom 10 --verbose
  fi
done
