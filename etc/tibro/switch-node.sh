#!/bin/sh
NODES_DIR="/etc/tibro/nodes"
CONF="/etc/tibro/tibro.conf"
LOG="/var/log/tibro.log"
LOCKFILE="/var/run/tibro-switch.lock"

PROVIDER="$1"
NODE_IDX="$2"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

do_switch() {
    save_active() {
        sed -i "s/^ACTIVE_PROVIDER=.*/ACTIVE_PROVIDER=\"${PROVIDER}\"/" "$CONF"
        sed -i "s/^ACTIVE_NODE=.*/ACTIVE_NODE=\"${NODE_IDX}\"/" "$CONF"
    }

    NODE_FILE="$NODES_DIR/${PROVIDER}.json"
    if [ ! -f "$NODE_FILE" ]; then
        log "ОШИБКА: файл нод не найден: $NODE_FILE"
        return 1
    fi

    save_active
    log "Переключение на провайдер=$PROVIDER нода=$NODE_IDX, перезапуск через procd..."

    /etc/init.d/tibro-xray restart

    sleep 3
    PID=$(pgrep -f "/usr/bin/xray -c /etc/tibro/config.json" | head -1)
    if [ -n "$PID" ]; then
        log "xray запущен PID=$PID провайдер=$PROVIDER нода=$NODE_IDX (через procd)"
    else
        log "ОШИБКА: xray не запустился после restart"
    fi

    sleep 3
    if nslookup google.com 127.0.0.1 >/dev/null 2>&1; then
        echo "[$(date '+%H:%M:%S')] DNS OK после переключения на $PROVIDER/$NODE_IDX" >> /var/log/tibro-health.log
    else
        echo "[$(date '+%H:%M:%S')] DNS FAIL после переключения на $PROVIDER/$NODE_IDX — возможна проблема с UDP у этой ноды" >> /var/log/tibro-health.log
    fi
}

(
    flock 200
    do_switch
) 200>"$LOCKFILE" &
WORKER_PID=$!

(
    i=0
    while [ $i -lt 90 ]; do
        kill -0 "$WORKER_PID" 2>/dev/null || exit 0
        sleep 1
        i=$((i+1))
    done
    if kill -0 "$WORKER_PID" 2>/dev/null; then
        kill -9 "$WORKER_PID" 2>/dev/null
        rm -f "$LOCKFILE"
        log "ОШИБКА: переключение $PROVIDER/$NODE_IDX зависло дольше 90с — принудительно прервано"
    fi
) &

wait "$WORKER_PID" 2>/dev/null
