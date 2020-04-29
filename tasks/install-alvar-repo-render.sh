#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-render-service.git
cd alvarcarto-render-service

if [ "$ALVAR_ENV" != "docker" ]; then
  mkdir -p $ALVAR_MAP_SERVER_DATA_DIR/tmp-downloads
  echo "Installing cron task to remove temp downloads .."
  (crontab -l 2>/dev/null; echo "0 * * * * /bin/bash -c 'find $ALVAR_MAP_SERVER_DATA_DIR/tmp-downloads -type f -name \"*\" -delete'") | crontab -
fi

nvm use 8.17.0
npm install
npm run build-posters
