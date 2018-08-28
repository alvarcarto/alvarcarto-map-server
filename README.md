# Map server

Requirements:

* Fresh Ubuntu 18.04 installation
* At least 16GB RAM for the installation phase. 32GB minimum is recommended for production.
* 450GB disk space (tested: 350GB disk space was not enough)

The full planet import should be done in a dedicated OVH server.

See [DigitalOcean install](#digitalocean-install) for QA install example.

This package will:

* Install Mapnik and tile serving plugins
* Install Postgres 10 with Postgis extension
* Install Mapnik & OSM data related tools
* Download [latest planet OSM data](http://planet.openstreetmap.org/)
* Download necessary shapefiles required by [openstreetmap-carto](https://github.com/gravitystorm/openstreetmap-carto) and our themes

    All Mapnik stylesheets should be modified to reference to following files:

    * `$ALVAR_MAP_SERVER_DATA_DIR/land-polygons-split-3857/land_polygons.shp`
    * `$ALVAR_MAP_SERVER_DATA_DIR/simplified-land-polygons-complete-3857/simplified_land_polygons.shp`
    * `$ALVAR_MAP_SERVER_DATA_DIR/ne_10m_admin_0_boundary_lines_land/ne_10m_admin_0_boundary_lines_land.shp`
    * `$ALVAR_MAP_SERVER_DATA_DIR/ne_110m_admin_0_countries/ne_110m_admin_0_countries.shp`

    Where `$ALVAR_MAP_SERVER_DATA_DIR` is the directory specified in [install.sh](install.sh)
    variables. The default is `/home/alvar/data`.
    Note that changing this may require to change this path in render/tile service code.
* Install Google Fonts
* Simplify downloaded .shp files using `shapeindex`.
* Import latest OSM data to Postgis server using [osm2psql](github.com/openstreetmap/osm2pgsql). [imposm3](https://github.com/omniscale/imposm3) was an alternative but openstreetmap style worked better.

## Installing

As root in the remote server, create `alvar` user:

```
adduser alvar
adduser alvar sudo
```

Installing map server is automated with [install.sh](install.sh).


**Note! Configure install.sh variables to suit the installation environment.
The variables define data directory which should have at least 450GB free disk
space. The default data directory is `/mnt/volume1/alvar`.**

Start a new ssh session with `ssh alvar@<ip>`. In the remote server, run:

```
sudo apt-get install -y screen nano git

# Increase scrollback to 500k lines
echo "defscrollback 500000" >> ~/.screenrc
echo "deflog on" >> ~/.screenrc
echo "logfile /home/alvar/screenlog.%n" >> ~/.screenrc

git clone https://alvarcarto-integration:fab7f21687f2cea5dfb2971ea69821b5e5cb87a2@github.com/kimmobrunfeldt/alvarcarto-map-server.git
cd alvarcarto-map-server

# Add:
#    Defaults    timestamp_timeout=-1
# to sudo configuration to extend the sudo timeout
#
# REMEMBER: remove the infinite timeout after install!
EDITOR=nano sudo visudo
```

Also disallow root SSH login:

```
sudo nano /etc/ssh/sshd_config
# And set PermitRootLogin no

# Restart
service ssh restart
```

If this is a QA install, change:

* `ALVAR_ENV=qa`
* `ALVAR_MAP_SERVER_DATA_DIR=/mnt/volume1/alvar`

in install.sh.

Add public cert and private key for Caddy:

```
sudo mkdir -p /etc/caddy

# Add cert from 1password (*.alvarcarto.com and apex cert by CloudFlare)
sudo nano /etc/caddy/cert.pem

# Add private key from 1password
sudo nano /etc/caddy/key.pem

sudo chown www-data:www-data /etc/caddy/cert.pem /etc/caddy/key.pem
sudo chmod 644 /etc/caddy/cert.pem
sudo chmod 600 /etc/caddy/key.pem
```

Then run:

```
screen -S install
./install.sh
```

Now the server should have all the components installed and node processes
running. **Go through [Testing installation](#testing-installation).**

**Note:** sudo password is asked a couple of times. When the osm2psql import starts,
you'll know nothing is prompted at least for the next 15 hours.

Now press `Ctrl` + `a` + `d` and wait. With the DigitalOcean example machine,
it takes around 70 hours. `osm2psql` takes most of the time: 63h34m.

If this is a QA install, remember to scale down DO droplet after install.

## Testing installation

What you should test after the install:

* Run `sudo reboot` and see if node processes are automatically spawned on boot
* Verify that CloudFlare origin certificates have been correctly installed
* Run [snapshot tool](https://github.com/kimmobrunfeldt/alvarcarto-render-snapshot) to verify that posters are still correctly generated

### Warming caches

```bash
npm i -g @alvarcarto/tilewarm

curl -O https://raw.githubusercontent.com/alvarcarto/tilewarm/master/geojson/world.geojson
tilewarm 'http://54.36.173.210:8002/bw/{z}/{x}/{y}/tile.png' --input world.geojson -c 10 --zoom 1-8 --verbose
tilewarm 'http://54.36.173.210:8002/gray/{z}/{x}/{y}/tile.png' --input world.geojson -c 10 --zoom 1-8 --verbose
tilewarm 'http://54.36.173.210:8002/black/{z}/{x}/{y}/tile.png' --input world.geojson -c 10 --zoom 1-8 --verbose
tilewarm 'http://54.36.173.210:8002/copper/{z}/{x}/{y}/tile.png' --input world.geojson -c 10 --zoom 1-8 --verbose
tilewarm 'http://54.36.173.210:8002/petrol/{z}/{x}/{y}/tile.png' --input world.geojson -c 10 --zoom 1-8 --verbose
```

After that, go to tiles cache folder and run `find . -name '*' -size 0 -print0` to find
possible tiles which are 0 bytes (incorrect render).


## DigitalOcean Install (QA)

Fire up a new Droplet and an SSD Volume:

* First create an 1GB droplet with 50GB SSD Block storage attached
* Resize the droplet to 16GB Memory, 8 Core Processor, 160GB SSD Disk, 6TB Transfer ($160/mo)

This allows changing the droplet size back to 1GB RAM when it's not used.

1. Login as root. You will get the root password of the droplet to your email.
2. Set root password and alvar user password as in 1password.
3. Go to https://cloud.digitalocean.com/droplets/volumes and click "More" link near the attached Volume. Press "Config instructions".
4. Copy the instructions to an editor. Replace all `/mnt/volume-fra1-01` references with `/mnt/volume1`.
5. Follow the instructions until you have /mnt/volume1 available in the Droplet.

After following the software install steps, remember to scale down the droplet for runtime.



## Common tasks

### Reload pm2 config

```bash
nvm use 6
pm2 stop all
pm2 delete all
cd $HOME/alvarcarto-map-server
pm2 start confs/pm2.json

# Check that everything went allright
pm2 logs --lines 1000

# Then save the startup:
sudo env PATH=$PATH:/home/alvar/.nvm/versions/node/v6.9.4/bin /home/alvar/.nvm/versions/node/v6.9.4/lib/node_modules/pm2/bin/pm2 startup systemd -u alvar --hp /home/alvar
pm2 save

```


### Investigate Caddy problems

**HTTP Access logs:**

`cat /var/log/access.log`

**Caddy errors:**

`sudo cat /var/log/syslog` or `sudo journalctl -u caddy`

**Edit Caddyfile:**

```
sudo nano /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

**Edit /etc/systemd/system/caddy.service**

```bash
sudo nano /etc/systemd/system/caddy.service
sudo systemctl daemon-reload
sudo systemctl restart caddy
```


## Known errors

### Mapnik `make test` fails

First it may fail to: `Postgis Plugin: FATAL:  role "alvar" does not exist`.

Fix:
```
sudo su postgres
psql
CREATE USER alvar;
ALTER USER alvar CREATEDB;
```

Then it may fail to: `ERROR (Postgis Plugin: FATAL:  database "template_postgis" does not exist`.

Fix, create postgis_template:

```
sudo su postgres
createdb template_postgis -E UTF-8
createlang plpgsql template_postgis  # may say this is already done
psql -d template_postgis -f /usr/share/postgresql/9.5/contrib/postgis-2.2/postgis.sql
psql -d template_postgis -f /usr/share/postgresql/9.5/contrib/postgis-2.2/spatial_ref_sys.sql
psql
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';
```

Or read more how to create template_postgis: https://wiki.archlinux.org/index.php/PostGIS


### Network is very slow

https://askubuntu.com/questions/574569/apt-get-stuck-at-0-connecting-to-us-archive-ubuntu-com

```
sudo nano /etc/gai.conf
```

and change line ~54 to uncomment the following:

```
precedence ::ffff:0:0/96  100
```

**Note: NOT THIS LINE: `precedence ::ffff:0:0/96  10`**



## Local install on Macbook

```
osm2pgsql -U osm -d osm -H localhost -P 5432 --create --slim \
  --flat-nodes ~/code/alvarcarto/osm2pgsql_flat_nodes.bin \
  --cache 14000 --number-processes 8 --hstore \
  --style openstreetmap-carto.style --multi-geometry \
  ../finland-latest.osm.pbf
```
