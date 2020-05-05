FROM ubuntu:18.04

ENV ALVAR_MAP_SERVER_REPOSITORY_DIR=/home/alvar/alvarcarto-map-server
ENV ALVAR_MAP_SERVER_INSTALL_DIR=/home/alvar
ENV ALVAR_MAP_SERVER_DATA_DIR=/home/alvar/data
ENV ALVAR_ENV=docker


# Setup ubuntu ready before running our scripts
RUN apt-get autoclean && apt-get autoremove && apt-get update && \
        apt-get -y install sudo openssl

# Set the locale
RUN apt-get -y install locales && locale-gen en_US.UTF-8

# Install software for convenience
RUN apt-get install -y postgresql-client

# WARNING: DO NOT use this solution in production, it is meant ONLY for local development.
#          This docker setup is not secure!
RUN bash -c 'useradd --shell /bin/bash --create-home --home /home/alvar --password "$(openssl passwd -1 alvar)" alvar' && \
        adduser alvar sudo

# Copy project
RUN mkdir -p $ALVAR_MAP_SERVER_REPOSITORY_DIR
COPY confs $ALVAR_MAP_SERVER_REPOSITORY_DIR/confs
COPY tasks $ALVAR_MAP_SERVER_REPOSITORY_DIR/tasks
COPY install.sh $ALVAR_MAP_SERVER_REPOSITORY_DIR/
RUN chown -R alvar:alvar $ALVAR_MAP_SERVER_REPOSITORY_DIR

RUN ls -l $ALVAR_MAP_SERVER_REPOSITORY_DIR
WORKDIR $ALVAR_MAP_SERVER_REPOSITORY_DIR

# Create data dir
RUN mkdir -p $ALVAR_MAP_SERVER_DATA_DIR
RUN chown -R alvar:alvar $ALVAR_MAP_SERVER_DATA_DIR

# Always use visudo for editing, but in this case we need a non-interactive command
# Also there is no risk that we would lock ourselves out of the system, we can just re-create
# the docker container.
# Disable password for alvar user in this docker container
RUN bash -c 'echo -e "\nalvar ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers'
RUN cat /etc/sudoers

USER alvar

