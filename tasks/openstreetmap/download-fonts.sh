#!/bin/bash

set -e
set -x

# For openstreetmap-carto
sudo apt-get install -y fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted ttf-unifont

# Install all google fonts for Alvar Carto styles
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/openstreetmap/install-google-fonts.sh
