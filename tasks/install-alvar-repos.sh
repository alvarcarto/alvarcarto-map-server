#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y libcairo2-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
git clone https://alvarcarto:b87a485f25d9ea03b77f46deb9348eb541020c13@github.com/kimmobrunfeldt/alvarcarto-render-service.git
cd alvarcarto-render-service
npm install
npm run build

cd $HOME
git clone https://alvarcarto:b87a485f25d9ea03b77f46deb9348eb541020c13@github.com/kimmobrunfeldt/alvarcarto-cartocss.git
cd alvarcarto-cartocss
nvm install 6.9.4
npm install
mkdir -p $HOME/mapnik-styles
./node_modules/.bin/carto styles/bw/project.mml > $HOME/mapnik-styles/bw.xml
cp -r $HOME/osm/openstreetmap-carto/data $HOME/mapnik-styles

cd $HOME
mkdir -p $ALVAR_MAP_SERVER_DATA_DIR/tiles/
git clone https://alvarcarto:b87a485f25d9ea03b77f46deb9348eb541020c13@github.com/kimmobrunfeldt/alvarcarto-tile-service.git
cd alvarcarto-tile-service

nvm use 6.9.4
npm install

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
npm install -g pm2

if [ "$ALVAR_ENV" = "qa" ]; then
    pm2 start confs/pm2.qa.json
else
    pm2 start confs/pm2.json
fi

sudo env PATH=$PATH:/home/alvar/.nvm/versions/node/v6.9.4/bin /home/alvar/.nvm/versions/node/v6.9.4/lib/node_modules/pm2/bin/pm2 startup systemd -u alvar --hp /home/alvar
