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
