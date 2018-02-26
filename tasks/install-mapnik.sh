#!/bin/bash

set -e
set -x

cd $HOME
git clone https://github.com/mapnik/mapnik mapnik-3.x
cd mapnik-3.x
git checkout v3.0.18
git submodule update --init
sudo apt-get install -y python python-dev curl zlib1g-dev clang make pkg-config protobuf-compiler

# Mason should install these deps in bootstrap.sh:
#sudo apt-get install -y \
#    libboost-all-dev \
#    libicu-dev \
#    libxml2 libxml2-dev \
#    libfreetype6 libfreetype6-dev \
#    libjpeg-dev \
#    libpng-dev \
#    libwebp-dev \
#    libproj-dev \
#    libtiff-dev \
#    libcairo2 libcairo2-dev python-cairo python-cairo-dev \
#    libcairomm-1.0-1v5 libcairomm-1.0-dev \
#    libgdal1-dev python-gdal \
#    libsqlite3-dev \
#    ttf-unifont ttf-dejavu ttf-dejavu-core ttf-dejavu-extra \
#    git build-essential python-nose

source bootstrap.sh
./configure CUSTOM_CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"
JOBS=8 make
make test
sudo make install

sudo apt-get install -y mapnik-utils
sudo apt-get install -y python-pip

pip install nik2img mapnik
