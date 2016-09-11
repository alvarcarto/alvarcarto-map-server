#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

NEW_POSTGRES_DATA_DIRECTORY=$ALVAR_MAP_SERVER_DATA_DIR/pg-data
POSTGRES_DEFAULT_DATA_DIRECTORY=/var/lib/postgresql/9.5/main

if [ -d "$NEW_POSTGRES_DATA_DIRECTORY" ]; then
  echo "$NEW_POSTGRES_DATA_DIRECTORY already exists! Aborting.."
  exit 1
fi

sudo apt-get install -y postgresql-9.5 postgresql-9.5-postgis-2.2

# Move data directory to bigger volume
sudo /etc/init.d/postgresql stop

# Copy existing postgres data to the new location and create a symlink
# from the default location to the new one
sudo cp -r $POSTGRES_DEFAULT_DATA_DIRECTORY $NEW_POSTGRES_DATA_DIRECTORY
sudo chown -R postgres:postgres $NEW_POSTGRES_DATA_DIRECTORY
sudo chmod 700 $NEW_POSTGRES_DATA_DIRECTORY
sudo rm -rf $POSTGRES_DEFAULT_DATA_DIRECTORY
sudo ln -s $NEW_POSTGRES_DATA_DIRECTORY $POSTGRES_DEFAULT_DATA_DIRECTORY

sudo /etc/init.d/postgresql start

# Setup osm database
sudo -u postgres psql -c "CREATE DATABASE osm;"
sudo -u postgres psql -d osm -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -c "CREATE USER osm WITH PASSWORD 'osm';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm to osm;"
