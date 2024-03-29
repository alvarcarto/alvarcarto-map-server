#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $ALVAR_MAP_SERVER_INSTALL_DIR
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-placement-service.git
cd alvarcarto-placement-service
sudo apt-get install -y imagemagick

nvm use 10.20.1
npm install
