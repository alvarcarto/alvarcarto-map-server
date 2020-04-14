FROM alvar-map-base

# These need to be run in the same command because we want postgres to be running in the background
# while doing data import. Not the most elegant docker way but works.
RUN bash -c 'bash tasks/install-and-configure-postgres.sh && \
             cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && \
             bash tasks/download-pbf.sh && \
             cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && \
             bash tasks/openstreetmap/install-osm-style-repo.sh && \
             cd $ALVAR_MAP_SERVER_REPOSITORY_DIR && \
             bash tasks/openstreetmap/install-osm2psql-and-import.sh && \
             sudo /etc/init.d/postgresql stop && \
             echo "Waiting for postgres to stop .. " && \
             sleep 5'

USER postgres
EXPOSE 5432

ENV PGDATA /var/lib/postgresql/10/main
CMD ["/usr/lib/postgresql/10/bin/postgres"]
