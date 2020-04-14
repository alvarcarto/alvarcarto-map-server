FROM alvar-map-base

# Install base dependencies
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/install-node.sh
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/install-mapnik.sh
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/openstreetmap/install-osm-style-repo.sh
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/openstreetmap/install-fonts.sh

# Install custom code
RUN sudo apt-get install -y libcairo2-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/install-alvar-repo-cartocss.sh
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/install-alvar-repo-render.sh
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/install-alvar-repo-placement.sh
RUN cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && bash tasks/install-alvar-repo-tile.sh
