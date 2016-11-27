# Map server

Requirements:

* Fresh Ubuntu 16.04 installation
* At least 16GB RAM for the installation phase
* 450GB disk space (tested: 350GB disk space was not enough)

See [DigitalOcean install](#digitalocean-install) to complete example.

This package will:

* Install Mapnik and tile serving plugins
* Install Postgres 9.5 with Postgis extension
* Install Mapnik & OSM data related tools
* Download [latest planet OSM data](http://planet.openstreetmap.org/)
* Download necessary shapefiles required by [lyrk-mapstyle](https://github.com/lyrk/lyrk-mapstyle/) and our themes

    All Mapnik stylesheets should be modified to reference to following files:

    * `$ALVAR_MAP_SERVER_DATA_DIR/land-polygons-split-3857/land_polygons.shp`
    * `$ALVAR_MAP_SERVER_DATA_DIR/simplified-land-polygons-complete-3857/simplified_land_polygons.shp`
    * `$ALVAR_MAP_SERVER_DATA_DIR/ne_10m_admin_0_boundary_lines_land/ne_10m_admin_0_boundary_lines_land.shp`
    * `$ALVAR_MAP_SERVER_DATA_DIR/ne_110m_admin_0_countries/ne_110m_admin_0_countries.shp`

    Where `$ALVAR_MAP_SERVER_DATA_DIR` is the directory specified in [install.sh](install.sh)
    variables. The default is `/mnt/volume1/alvar`.
* Simplify downloaded .shp files using `shapeindex`.
* Import latest OSM data to Postgis server using [imposm3](https://github.com/omniscale/imposm3)

## Usage

As root in the remote server, create `alvar` user:

```
adduser alvar
adduser alvar sudo
```

Installing map server is automated with [install.sh](install.sh).

In your local computer, run:

```
export SERVER_USER=alvar
export SERVER_IP=alvar-map2

mkdir tmp
cd tmp
git clone git@github.com:kimmobrunfeldt/alvarcarto-map-server.git alvarcarto-map-server

rm -rf alvarcarto-map-server/.git
tar cvvfz alvarcarto-map-server.tar.gz alvarcarto-map-server

scp alvarcarto-map-server.tar.gz $SERVER_USER@$SERVER_IP:~

cd ..
rm -r tmp

ssh $SERVER_USER@$SERVER_IP
```
where $SERVER_USER should be a sudo user in $SERVER_IP server.


**Note! Configure install.sh variables to suit the installation environment.
The variables define data directory which should have at least 450GB free disk
space. The default data directory is `/mnt/volume1/alvar`.**

In the remote server, run:

```
sudo apt-get install -y screen
tar xvvfz alvarcarto-map-server.tar.gz
cd alvarcarto-map-server

screen -S install
./install.sh
```

**Note:** sudo password is asked a couple of times. When the imposm3 import starts,
you'll know nothing is prompted at least for the next 15 hours.

Now press `Ctrl` + `a` + `d` and wait. With the DigitalOcean example machine,
it takes around 70 hours. `imposm3` takes most of the time: 63h34m.


## DigitalOcean Install

Fire up a new Droplet and an SSD Volume:

* 16GB Memory, 8 Core Processor, 160GB SSD Disk, 6TB Transfer ($160/mo)
* 450GB SSD Block storage attached

1. Login as root. You will get the root password of the droplet to your email.
2. Set root password and alvar user password as in 1password.
3. Go to https://cloud.digitalocean.com/droplets/volumes and click "More" link near the attached Volume. Press "Config instructions".
4. Copy the instructions to an editor. Replace all `/mnt/volume-fra1-01` references with `/mnt/volume1`.
5. Follow the instructions until you have /mnt/volume1 available in the Droplet.



## Fonts

Required:

```
/mnt/volume1/alvar/fonts/dejavu-fonts-ttf-2.37/DejaVuSans-Bold.ttf
/mnt/volume1/alvar/fonts/dejavu-fonts-ttf-2.37/DejaVuSans.ttf
/mnt/volume1/alvar/fonts/unifont/unifont-9.0.02.ttf
/mnt/volume1/alvar/fonts/opensans/OpenSans-Bold.ttf
/mnt/volume1/alvar/fonts/opensans/OpenSans-SemiboldItalic.ttf
/mnt/volume1/alvar/fonts/opensans/OpenSans-Semibold.ttf
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
