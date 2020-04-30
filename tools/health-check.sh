#!/bin/bash

set -e
set -x

LOG_FILE="$HOME/health_cronlog.log"

# All these requests are from Helsinki area

# Tile service
status_code=$(curl --silent --output /dev/stderr --write-out "%{http_code}" 'http://localhost:8002/bw/13/4665/2367/tile.png')
if [ $status_code -ne 200 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Tile service request failed with code $status_code! Restarting .." >> $LOG_FILE
  pm2 restart tile
  sleep 30
fi

# Render service
status_code=$(curl --silent --output /dev/stderr --write-out "%{http_code}" 'http://localhost:8001/api/raster/render?swLat=60.04&swLng=24.73&neLat=60.37&neLng=25.20&mapStyle=bw&posterStyle=sharp&size=50x70cm&orientation=portrait&labelsEnabled=true&labelHeader=Helsinki&labelSmallHeader=Finland&labelText=60.209°N%20%2F%2024.973°E&resizeToWidth=500')
if [ $status_code -ne 200 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Render service request failed with code $status_code! Restarting .." >> $LOG_FILE
  pm2 restart render
  sleep 30
fi

# Placement service
status_code=$(curl --silent --output /dev/stderr --write-out "%{http_code}" 'http://localhost:8003/api/place-map/no-flowers-in-blue-black-frame?swLat=60.04&swLng=24.73&neLat=60.37&neLng=25.20&mapStyle=bw&posterStyle=sharp&labelsEnabled=true&labelHeader=Helsinki&labelSmallHeader=Finland&labelText=60.209°N%20%2F%2024.973°E&resizeToWidth=400')
if [ $status_code -ne 200 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Placement service request failed with code $status_code! Restarting .." >> $LOG_FILE
  pm2 restart placement
  sleep 30
fi

# http-cache service
status_code=$(curl --silent --output /dev/stderr --write-out "%{http_code}" 'http://localhost:8004/placement/api/place-map/no-flowers-in-blue-black-frame?swLat=60.04&swLng=24.73&neLat=60.37&neLng=25.20&mapStyle=bw&posterStyle=sharp&labelsEnabled=true&labelHeader=Helsinki&labelSmallHeader=Finland&labelText=60.209°N%20%2F%2024.973°E&resizeToWidth=400')
if [ $status_code -ne 200 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') http-cache service request failed with code $status_code! Restarting .." >> $LOG_FILE
  pm2 restart http-cache
  sleep 30
fi
