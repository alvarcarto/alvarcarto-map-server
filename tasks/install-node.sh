#!/bin/bash

set -e
set -x

sudo apt-get install -y wget

wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.31.7/install.sh | bash

# Needed, otherwise error: tasks/install-node.sh: line 11: /home/alvar/.bashrc: No such file or directory
touch $HOME/.bashrc

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

source ~/.bashrc

nvm install 8.17.0

nvm install 10.8.0
nvm use 10.8.0
nvm alias default 10.8.0
echo "nvm use 10.8.0" >> ~/.bashrc
