#!/bin/bash

set -e
set -x

mkdir -p fonts
cd fonts

mkdir unifont
cd unifont
wget http://unifoundry.com/pub/unifont-9.0.02/font-builds/unifont-9.0.02.ttf
cd ..

wget http://sourceforge.net/projects/dejavu/files/dejavu/2.37/dejavu-fonts-ttf-2.37.tar.bz2
tar vxjf dejavu-fonts-ttf-2.37.tar.bz2

mkdir opensans
cd opensans
wget https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-Semibold.ttf
wget https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-SemiboldItalic.ttf
wget https://github.com/google/fonts/raw/master/apache/opensans/OpenSans-Bold.ttf

cd ../..
