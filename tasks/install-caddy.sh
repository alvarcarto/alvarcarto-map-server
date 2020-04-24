#!/bin/bash

set -e
set -x
[ -z "$ALVAR_MAP_SERVER_DATA_DIR" ] && echo "ALVAR_MAP_SERVER_DATA_DIR environment variable is not set." && exit 1;

sudo apt-get install -y libcap2-bin libnss3-tools

wget https://github.com/caddyserver/caddy/releases/download/v2.0.0-rc.3/caddy_2.0.0-rc.3_linux_amd64.tar.gz
mkdir caddy_2.0.0-rc.3_linux_amd64
cd caddy_2.0.0-rc.3_linux_amd64
tar zxvvf ../caddy_2.0.0-rc.3_linux_amd64.tar.gz

# Following these instructions https://github.com/mholt/caddy/tree/master/dist/init/linux-systemd

sudo cp caddy /usr/bin
sudo chown root:root /usr/bin/caddy
sudo chmod 755 /usr/bin/caddy

# Increase file descriptor limit
sudo bash -c 'echo "* soft nofile 8192" >> /etc/security/limits.conf'
sudo bash -c 'echo "* hard nofile 8192" >> /etc/security/limits.conf'

# Give the caddy binary the ability to bind to privileged ports (e.g. 80, 443) as a non-root user:
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/caddy

# Set up the user, group, and directories that will be needed:

sudo groupadd --system caddy
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy

sudo mkdir -p /etc/caddy
sudo chown root:caddy /etc/caddy
sudo mkdir /etc/ssl/caddy
sudo chown -R caddy:root /etc/ssl/caddy
sudo chmod 0770 /etc/ssl/caddy

# Setup config file
sudo cp $ALVAR_MAP_SERVER_REPOSITORY_DIR/confs/Caddyfile /etc/caddy/
sudo chown caddy:caddy /etc/caddy/Caddyfile
sudo chmod 444 /etc/caddy/Caddyfile

sudo cp $ALVAR_MAP_SERVER_REPOSITORY_DIR/confs/caddy.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/caddy.service
sudo chmod 644 /etc/systemd/system/caddy.service
sudo systemctl daemon-reload
sudo systemctl start caddy.service

# Enable automatic on boot
sudo systemctl enable caddy.service

# Add access.log if it doesn't yet exist
sudo mkdir -p /var/log/caddy
sudo chown caddy:caddy /var/log/caddy
sudo touch /var/log/caddy/access.log
sudo chown caddy:caddy /var/log/caddy/access.log

# Debugging, see README

echo -e "\n\n\n---------------------------------\n"
echo -e "REMEMBER TO ADD /etc/caddy/cert.pem AND /etc/caddy/key.pem"
echo -e "\n---------------------------------\n\n\n"

