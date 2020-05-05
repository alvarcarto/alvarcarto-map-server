#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $ALVAR_MAP_SERVER_INSTALL_DIR
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-cartocss.git
cd alvarcarto-cartocss

nvm use 10.20.1
npm install
npm run build
mkdir -p $ALVAR_MAP_SERVER_INSTALL_DIR/mapnik-styles
cp -r dist/*.xml $ALVAR_MAP_SERVER_INSTALL_DIR/mapnik-styles
cp -r $ALVAR_MAP_SERVER_INSTALL_DIR/osm/openstreetmap-carto/data $ALVAR_MAP_SERVER_INSTALL_DIR/mapnik-styles
