#!/bin/bash

set -e
set -x

sudo apt-get update
sudo apt-get upgrade

cd $HOME
git clone https://github.com/mapnik/mapnik mapnik-3.x --depth 10
cd mapnik-3.x
git submodule update --init
sudo apt-get install python zlib1g-dev clang make pkg-config
source bootstrap.sh
./configure CUSTOM_CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"
make
make test
sudo make install
