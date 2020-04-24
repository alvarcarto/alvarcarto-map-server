#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-http-cache-service.git
cd alvarcarto-http-cache-service

mkdir -p $ALVAR_MAP_SERVER_DATA_DIR/http-cache/

nvm use 10.8.0
npm install
