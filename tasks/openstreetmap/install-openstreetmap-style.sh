#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/openstreetmap/install-osm-style-repo.sh
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/openstreetmap/install-osm2psql-and-import.sh
source $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks/openstreetmap/install-fonts.sh
