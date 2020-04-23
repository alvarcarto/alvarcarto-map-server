#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

export TZ=Europe/Helsinki
export DEBIAN_FRONTEND=noninteractive
sudo DEBIAN_FRONTEND=$DEBIAN_FRONTEND TZ=$TZ apt-get install -y tzdata

NEW_POSTGRES_DATA_DIRECTORY=$ALVAR_MAP_SERVER_DATA_DIR/pg-data
POSTGRES_DEFAULT_DATA_DIRECTORY=/var/lib/postgresql/10/main

if [ -d "$NEW_POSTGRES_DATA_DIRECTORY" ]; then
  echo "$NEW_POSTGRES_DATA_DIRECTORY already exists! Aborting.."
  exit 1
fi

sudo apt-get install -y postgresql-10 postgresql-10-postgis-2.4

if [ "$ALVAR_ENV" != "docker" ]; then
  sudo systemctl enable postgresql.service
  sudo systemctl stop postgresql.service
else
  sudo /etc/init.d/postgresql stop
fi

echo "Waiting for postgres to stop .. "
sleep 5

# Move data directory to bigger volume
# Copy existing postgres data to the new location and create a symlink
# from the default location to the new one
sudo cp -r $POSTGRES_DEFAULT_DATA_DIRECTORY $NEW_POSTGRES_DATA_DIRECTORY
sudo rm -rf $POSTGRES_DEFAULT_DATA_DIRECTORY
sudo ln -s $NEW_POSTGRES_DATA_DIRECTORY $POSTGRES_DEFAULT_DATA_DIRECTORY

if [ "$ALVAR_ENV" = "qa" ]; then
    echo -e "Choosing qa postgres config .. "
    sudo cp confs/postgresql.qa.conf confs/chosen-postgresql.conf
elif [ "$ALVAR_ENV" = "docker" ]; then
    echo -e "Choosing docker postgres config .. "
    sudo cp confs/postgresql.docker.conf confs/chosen-postgresql.conf
else
    echo -e "Choosing production postgres config .. "
    sudo cp confs/postgresql.conf confs/chosen-postgresql.conf
fi

# https://stackoverflow.com/questions/47890233/postgresql-docker-could-not-bind-ipv6-socket-cannot-assign-requested-address
if [ "$ALVAR_ENV" == "docker" ]; then
  sudo bash -c 'echo -e "\n\nhost  all  all 0.0.0.0/0 md5" >> /var/lib/postgresql/10/main/pg_hba.conf'
  sudo bash -c 'echo -e "\n\nhost  all  all 0.0.0.0/0 md5" >> /etc/postgresql/10/main/pg_hba.conf'
fi

# I'm not sure why but docker reads postgres conf under /var, but pg_hba.confg under /etc,
# we copy configs to both locations "just in case"
echo -e "Copying postgres configuration .. "
sudo cp confs/chosen-postgresql.conf /etc/postgresql/10/main/postgresql.conf
sudo cp confs/chosen-postgresql.conf /var/lib/postgresql/10/main/postgresql.conf

sudo chown -R postgres:postgres $NEW_POSTGRES_DATA_DIRECTORY
sudo chmod 700 $NEW_POSTGRES_DATA_DIRECTORY
sudo chown postgres:postgres /etc/postgresql/10/main/postgresql.conf

if [ "$ALVAR_ENV" != "docker" ]; then
  sudo systemctl start postgresql.service
else
  sudo /etc/init.d/postgresql start
fi

# In few cases postgres hasn't
echo "Waiting for postgres to start up .. "
sleep 5

# Setup osm database
sudo -u postgres psql -c "CREATE DATABASE osm;"
sudo -u postgres psql -d osm -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -d osm -c "CREATE EXTENSION hstore;"
sudo -u postgres psql -c "CREATE USER osm WITH PASSWORD 'osm';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm to osm;"
