#!/bin/bash
# Flood Upgrade Script
# Author: liara

users=($(cat /etc/htpasswd | cut -d ":" -f 1))

if [[ ! $(which npm) ]] || [[ $(node --version) =~ "v6" ]]; then
  sed -i 's/node_6.x/node_8.x/g' /etc/apt/sources.list.d/nodesource.list >> $log 2>&1
  apt-get update -y -q >> $log 2>&1
  apt-get -y -q upgrade >> $log 2>&1
fi

if [[ ! $(which node-gyp) ]]; then
  npm install -g node-gyp >> $log 2>&1
fi

for u in "${users[@]}"; do
  port=$(grep floodServerPort /home/$u/.flood/config.js | cut -d: -f2 | sed 's/[^0-9]*//g')
  scgi=$(cat /home/$u/.rtorrent.rc | grep scgi | cut -d: -f2)
  salt=$(grep secret /home/$u/.flood/config.js | cut -d\' -f2)
  if [[ $(systemctl is-active flood@$u) == "active" ]]; then
    active=yes
    systemctl stop flood@$u
  fi
  cd /home/$u/.flood
  sudo -u $u git pull || (sudo -u $u git reset HEAD --hard; sudo -u $u git pull)
  rm -rf config.js
  cp -a config.template.js config.js
  sed -i "s/floodServerPort: 3000/floodServerPort: $port/g" config.js
  sed -i "s/port: 5000/port: $scgi/g" config.js
  sed -i "s/secret: 'flood'/secret: '$salt'/g" config.js
  if [[ ! -f /install/.nginx.lock ]]; then
    sed -i "s/floodServerHost: '127.0.0.1'/floodServerHost: '0.0.0.0'/g" config.js
  elif [[ -f /install/.nginx.lock ]]; then
    sed -i "s/floodServerHost: '0.0.0.0'/floodServerHost: '127.0.0.1'/g" /home/$u/.flood/config.js
    sed -i "s/baseURI: '\/'/baseURI: '\/flood'/g" /home/$u/.flood/config.js
  fi
  sudo -H -u $u npm install
  sudo -H -u $u npm run build || (rm -rf /home/$u/.flood/node_modules; sudo -H -u $u npm install; sudo -H -u $u npm run build)
  if [[ $active == "yes" ]]; then
    systemctl start flood@$u
  fi
done