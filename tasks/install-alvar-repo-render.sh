#!/bin/bash

set -e
set -x

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

cd $HOME
git clone https://alvarcarto-integration:c20a4fe9a8771c17eab5f0470fba434ab2fcf901@github.com/alvarcarto/alvarcarto-render-service.git
cd alvarcarto-render-service

nvm use 8.17.0
npm install
npm run build
npm run build-posters
