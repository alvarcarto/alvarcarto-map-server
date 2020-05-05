#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
mkdir -p $ALVAR_MAP_SERVER_DATA_DIR/tiles/
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-tile-service.git
cd alvarcarto-tile-service

nvm use 8.17.0
npm install

if [ "$ALVAR_ENV" != "docker" ]; then
  # Sometimes disk cache leaves zero byte tiles on disk
  echo "Installing cron task to remove zero byte tiles from cache .."
  # Run every 8th hour, since iterating through whole tiles folder is intensive
  echo -e "$(crontab -l 2>/dev/null)\n0 */8 * * * /bin/bash -c 'find $ALVAR_MAP_SERVER_DATA_DIR/tiles/ -type f -size 0 -delete'" | crontab -
fi
