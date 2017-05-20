#!/bin/bash

set -e
set -x

# For openstreetmap-carto
sudo apt-get install -y fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted ttf-unifont

# Install all google fonts for Alvar Carto styles
wget https://raw.githubusercontent.com/hotice/webupd8/c9bffcd240c71e2cba7aaaf5c28713d5e2fcda78/install-google-fonts
chmod +x install-google-fonts
./install-google-fonts
