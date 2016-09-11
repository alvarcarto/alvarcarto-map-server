# Map server

Requirements:

* Fresh Ubuntu 16.04 installation
* At least 16GB RAM for the installation phase
* 450GB disk space (tested: 350GB disk space was not enough)

For example in DigitalOcean:
* 16GB Memory, 8 Core Processor, 160GB SSD Disk, 6TB Transfer ($160/mo)
* 450GB SSD Block storage attached

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
export SERVER_IP=

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
sudo apt-get install screen
tar xvvfz alvarcarto-map-server.tar.gz
cd alvarcarto-map-server

screen -S install
./install.sh
```

Now press `Ctrl` + `a` + `d` and wait, it may take 6 - 48 hours to install.
