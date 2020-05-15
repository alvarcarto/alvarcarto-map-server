#!/bin/bash

# Original author: Michalis Georgiou <mechmg93@gmail.comr>
# Modified by Andrew http://www.webupd8.org <andrew@webupd8.org>
# Copied from: https://raw.githubusercontent.com/hotice/webupd8/c9bffcd240c71e2cba7aaaf5c28713d5e2fcda78/install-google-fonts

set -e
set -x

_branch="78303685d514cb0e80efc82538aa9818cdd95294"
_wgeturl="https://github.com/google/fonts/archive/$_branch.tar.gz"
_gf="google-fonts"

# install wget
sudo apt-get -y install wget fontconfig

# make sure a file with the same name doesn't already exist
rm -f $_gf.tar.gz

echo "Connecting to Github server..."
wget $_wgeturl -O $_gf.tar.gz

echo "Extracting the downloaded archive..."
tar -xf $_gf.tar.gz

echo "Creating the /usr/share/fonts/truetype/$_gf folder"
sudo mkdir -p /usr/share/fonts/truetype/$_gf

echo "Installing all .ttf fonts in /usr/share/fonts/truetype/$_gf"
find "$PWD/fonts-$_branch/" -name "*.ttf" -exec sudo install -m644 {} /usr/share/fonts/truetype/$_gf/ \; || return 1

mkdir -p noto-cjk
cd noto-cjk
echo "Installing noto font variations..."
_noto_branch="be6c059ac1587e556e2412b27f5155c8eb3ddbe6"
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-Black.otf
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-Bold.otf
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-DemiLight.otf
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-Light.otf
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-Medium.otf
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-Regular.otf
curl -O https://raw.githubusercontent.com/googlefonts/noto-cjk/$_noto_branch/NotoSansSC-Thin.otf

cd ..

echo "Creating the /usr/share/fonts/opentype/$_gf folder"
sudo mkdir -p /usr/share/fonts/opentype/$_gf

echo "Installing all .otf fonts in /usr/share/fonts/opentype/$_gf"
find "$PWD/noto-cjk/" -name "*.otf" -exec sudo install -m644 {} /usr/share/fonts/opentype/$_gf/ \; || return 1

echo "Updating the font cache"
fc-cache -f > /dev/null

# clean up, but only the .tar.gz, the user may need the folder
rm -f $_gf.tar.gz

echo "Done."
