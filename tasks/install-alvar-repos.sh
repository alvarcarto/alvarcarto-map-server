#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y libcairo2-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
git clone https://alvarcarto-integration:fab7f21687f2cea5dfb2971ea69821b5e5cb87a2@github.com/kimmobrunfeldt/alvarcarto-render-service.git
cd alvarcarto-render-service
nvm install 6.9.4
nvm use 6.9.4
npm install
npm run build
npm run build-posters

cd $HOME
git clone https://alvarcarto-integration:fab7f21687f2cea5dfb2971ea69821b5e5cb87a2@github.com/kimmobrunfeldt/alvarcarto-cartocss.git
cd alvarcarto-cartocss
nvm use 6.9.4
npm install
npm run build
mkdir -p $HOME/mapnik-styles
cp -r dist/*.xml $HOME/mapnik-styles
cp -r $HOME/osm/openstreetmap-carto/data $HOME/mapnik-styles

cd $HOME
mkdir -p $ALVAR_MAP_SERVER_DATA_DIR/tiles/
git clone https://alvarcarto-integration:fab7f21687f2cea5dfb2971ea69821b5e5cb87a2@github.com/kimmobrunfeldt/alvarcarto-tile-service.git
cd alvarcarto-tile-service
nvm use 6.9.4
nvm alias default 6.9.4
echo "nvm use 6.9.4" >> ~/.bashrc
npm install

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
npm install -g pm2

if [ "$ALVAR_ENV" = "qa" ]; then
    pm2 start confs/pm2.qa.json
else
    pm2 start confs/pm2.json
fi

sudo env PATH=$PATH:/home/alvar/.nvm/versions/node/v6.9.4/bin /home/alvar/.nvm/versions/node/v6.9.4/lib/node_modules/pm2/bin/pm2 startup systemd -u alvar --hp /home/alvar
