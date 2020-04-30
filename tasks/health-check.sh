#!/bin/bash

set -e
set -x

LOG_FILE="$HOME/health_cronlog.log"

# All these requests are from Helsinki area

# Render service
exit_code=0
curl --fail 'http://localhost:8001/api/raster/render?swLat=60.04&swLng=24.73&neLat=60.37&neLng=25.20&mapStyle=bw&posterStyle=sharp&size=50x70cm&orientation=portrait&labelsEnabled=true&labelHeader=Helsinki&labelSmallHeader=Finland&labelText=60.209°N%20%2F%2024.973°E&resizeToWidth=200' || exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Render service request failed! Restarting .." >> $LOG_FILE
  pm2 restart render
fi

# Tile service
exit_code=0
curl --fail 'http://localhost:8002/bw/13/4665/2367/tile.png'
if [ $exit_code -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Tile service request failed! Restarting .." >> $LOG_FILE
  pm2 restart tile
fi

# Placement service
exit_code=0
curl --fail 'http://localhost:8003/api/place-map/no-flowers-in-blue-black-frame?swLat=60.04&swLng=24.73&neLat=60.37&neLng=25.20&mapStyle=bw&posterStyle=sharp&labelsEnabled=true&labelHeader=Helsinki&labelSmallHeader=Finland&labelText=60.209°N%20%2F%2024.973°E&resizeToWidth=400' || exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Placement service request failed! Restarting .." >> $LOG_FILE
  pm2 restart placement
fi

# http-cache service
exit_code=0
curl --fail 'http://localhost:8004/placement/api/place-map/no-flowers-in-blue-black-frame?swLat=60.04&swLng=24.73&neLat=60.37&neLng=25.20&mapStyle=bw&posterStyle=sharp&labelsEnabled=true&labelHeader=Helsinki&labelSmallHeader=Finland&labelText=60.209°N%20%2F%2024.973°E&resizeToWidth=400' || exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') http-cache service request failed! Restarting .." >> $LOG_FILE
  pm2 restart http-cache
fi
