#!/bin/bash

set -e
set -x

wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.31.7/install.sh | bash

export NVM_DIR="/home/alvar/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

source ~/.bashrc

# Latest node version defined in tilelive .travis.yml
nvm install 5.12.0
nvm use 5.12.0
