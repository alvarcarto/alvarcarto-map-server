#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y libcairo2-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/install-alvar-repo-render.sh
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/install-alvar-repo-cartocss.sh
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/install-alvar-repo-placement.sh
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/install-alvar-repo-tile.sh


nvm use 10.8.0

cd $ALVAR_MAP_SERVER_REPOSITORY_DIR
npm install -g pm2

if [ "$ALVAR_ENV" = "qa" ] || [ "$ALVAR_ENV" = "docker" ]; then
    pm2 start confs/pm2.qa.json
else
    pm2 start confs/pm2.json
fi

sleep 3
sudo env PATH=$PATH:/home/alvar/.nvm/versions/node/v10.8.0/bin /home/alvar/.nvm/versions/node/v10.8.0/lib/node_modules/pm2/bin/pm2 startup systemd -u alvar --hp /home/alvar
sleep 2
pm2 save
