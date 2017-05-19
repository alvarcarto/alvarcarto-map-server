#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y libcairo2-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

cd $HOME
git clone https://alvarcarto:b87a485f25d9ea03b77f46deb9348eb541020c13@github.com/kimmobrunfeldt/alvarcarto-render-service.git
cd alvarcarto-render-service
npm install

cd $HOME
git clone https://alvarcarto:b87a485f25d9ea03b77f46deb9348eb541020c13@github.com/kimmobrunfeldt/alvarcarto-cartocss.git
cd alvarcarto-cartocss
npm install
 mkdir -p $HOME/mapnik-styles
./node_modules/.bin/carto styles/bw/project.mml > $HOME/mapnik-styles/bw.xml
cp -r $HOME/osm/openstreetmap-carto/data $HOME/mapnik-styles

cd $HOME
git clone https://alvarcarto:b87a485f25d9ea03b77f46deb9348eb541020c13@github.com/kimmobrunfeldt/alvarcarto-tile-service.git
cd alvarcarto-tile-service
nvm install 6.9.4
npm install