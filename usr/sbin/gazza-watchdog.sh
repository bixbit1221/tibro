#!/bin/sh
KEY="/root/.ssh/gazza_rsa"
VPS="78.46.185.182"
LOG="/var/log/gazza-watchdog.log"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

# Ждём сеть
i=0
while [ $i -lt 30 ]; do
    ping -c1 -W2 "$VPS" >/dev/null 2>&1 && break
    sleep 2
    i=$((i+1))
done

log "Watchdog запущен"

while true; do
    # Туннель 2224 → dropbear порт 22
    if ! ps | grep -v grep | grep -q "2224:127.0.0.1:22"; then
        log "Туннель 2224 упал — перезапускаем..."
        ssh -i "$KEY" -o StrictHostKeyChecking=no \
            -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
            -o ExitOnForwardFailure=yes \
            -fN -R 2224:127.0.0.1:22 root@${VPS} -p 22
        log "Туннель 2224 поднят"
    fi

    # Туннель 2225 → openssh порт 2222
    if ! ps | grep -v grep | grep -q "2225:127.0.0.1:2222"; then
        log "Туннель 2225 упал — перезапускаем..."
        ssh -i "$KEY" -o StrictHostKeyChecking=no \
            -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
            -o ExitOnForwardFailure=yes \
            -fN -R 2225:127.0.0.1:2222 root@${VPS} -p 22
        log "Туннель 2225 поднят"
    fi

    sleep 30
done
