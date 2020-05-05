#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-cartocss.git
cd alvarcarto-cartocss

nvm use 10.20.1
npm install
npm run build
mkdir -p $HOME/mapnik-styles
cp -r dist/*.xml $HOME/mapnik-styles
cp -r $HOME/osm/openstreetmap-carto/data $HOME/mapnik-styles

if [ "$1" != "warm_caches" ]; then
  echo "Skipping warm_caches step"
  exit 0;
fi


# WARNING: This operation takes a VERY LONG time
# Warm tile caches.

# https://discuss.circleci.com/t/globally-installed-node-module-yields-eacess-permission-denied/13608
sudo npm install -g @alvarcarto/tilewarm
curl -O https://raw.githubusercontent.com/alvarcarto/tilewarm/master/geojson/world.geojson
curl -O https://raw.githubusercontent.com/alvarcarto/tilewarm/master/geojson/all-cities.geojson

# Iterate all styles (~12) in cartocss repo
# For each style we need to fetch 80k + 13k = ~100k tiles, this totals 1.2M tile requests
# If request takes 1000ms on average, this process takes 333h ~= 14d
for i in $(find ./dist -name '*.xml');
do
  style=$(basename "$i" .xml)

  if [ "$ALVAR_SERVER_ENV" == "reserve" ]; then
    # 1-8 zoom levels for whole world is 80k tiles
    echo "Warming caches (production) with world.geojson for style $style .."
    NODE_OPTIONS=--max_old_space_size=4096 tilewarm "http://$IP:8002/bw/{z}/{x}/{y}/tile.png" --input world.geojson --max-retries 20 --retry-base-timeout 100 -c 'z < 8 ? 1 : 2' --zoom 1-8 --verbose

    # 9-10 zoom levels for all cities is 13k tiles
    echo "Warming caches (production) with all-cities.geojson for style $style .."
    NODE_OPTIONS=--max_old_space_size=4096 tilewarm "http://$IP:8002/bw/{z}/{x}/{y}/tile.png" --input all-cities.geojson --max-retries 10 --retry-base-timeout 100 -c 20 --zoom 10 --verbose
  else
    # 10 zoom level for all cities is 13k tiles
    echo "Warming caches (qa) with all-cities.geojson for style $style .."
    NODE_OPTIONS=--max_old_space_size=4096 tilewarm "http://$IP:8002/bw/{z}/{x}/{y}/tile.png" --input all-cities.geojson -c 20 --zoom 10 --verbose
  fi
done
