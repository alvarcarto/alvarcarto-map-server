#!/bin/bash

set -e
set -x

wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.31.7/install.sh | bash
source ~/.bashrc

# Latest node version defined in tilelive .travis.yml
nvm install 5
