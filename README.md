# Map server

Requirements:

* Fresh Ubuntu 16.04 installation
* 350GB disk space

This package will install:

* Mapnik and tile serving plugins
* Postgres 9.5 with Postgis extension
* Required tools to import OSM data into postgres

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
ssh $SERVER_USER@$SERVER_IP
```
where $SERVER_USER should be a sudo user in $SERVER_IP server.

In the remote server, run:

```
tar xvvfz alvarcarto-map-server.tar.gz
cd alvarcarto-map-server
./install.sh
```
