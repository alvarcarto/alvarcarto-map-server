#!/bin/bash

set -e
set -x

sudo apt-get install -y make cmake g++ libboost-dev libboost-system-dev \
  libboost-filesystem-dev libexpat1-dev zlib1g-dev \
  libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 \
  liblua5.2-dev

cd $HOME
git clone git://github.com/openstreetmap/osm2pgsql.git
cd osm2pgsql
mkdir build && cd build
cmake ..
JOBS=8 make
sudo make install

