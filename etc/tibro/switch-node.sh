#!/bin/sh
# /etc/tibro/switch-node.sh
# Использование: switch-node.sh <provider> <node_index>

XRAY_BIN="/usr/bin/xray"
XRAY_PID="/var/run/tibro-xray.pid"
CONFIG="/etc/tibro/config.json"
NODES_DIR="/etc/tibro/nodes"
CONF="/etc/tibro/tibro.conf"
LOG="/var/log/tibro.log"

PROVIDER="$1"
NODE_IDX="$2"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

stop_xray() {
    if [ -f "$XRAY_PID" ]; then
        OLD_PID=$(cat "$XRAY_PID")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            kill "$OLD_PID"
            sleep 1
            kill -0 "$OLD_PID" 2>/dev/null && kill -9 "$OLD_PID"
            log "Остановлен xray PID=$OLD_PID"
        fi
        rm -f "$XRAY_PID"
    fi
    pkill -x xray 2>/dev/null
    sleep 1
}

build_config() {
    NODE_FILE="$NODES_DIR/${PROVIDER}.json"
    if [ ! -f "$NODE_FILE" ]; then
        log "ОШИБКА: файл нод не найден: $NODE_FILE"
        exit 1
    fi
    sh /etc/tibro/build-config.sh "$NODE_FILE" "$NODE_IDX" > "$CONFIG"
    if [ $? -ne 0 ]; then
        log "ОШИБКА: не удалось собрать конфиг"
        exit 1
    fi
    log "Конфиг собран: провайдер=$PROVIDER нода=$NODE_IDX"
}

start_xray() {
    "$XRAY_BIN" -c "$CONFIG" >> /var/log/tibro-xray.log 2>&1 &
    NEW_PID=$!
    echo "$NEW_PID" > "$XRAY_PID"
    sleep 2
    if kill -0 "$NEW_PID" 2>/dev/null; then
        log "xray запущен PID=$NEW_PID провайдер=$PROVIDER нода=$NODE_IDX"
    else
        log "ОШИБКА: xray упал после запуска"
        rm -f "$XRAY_PID"
        exit 1
    fi
}

save_active() {
    sed -i "s/^ACTIVE_PROVIDER=.*/ACTIVE_PROVIDER=\"${PROVIDER}\"/" "$CONF"
    sed -i "s/^ACTIVE_NODE=.*/ACTIVE_NODE=\"${NODE_IDX}\"/" "$CONF"
}

stop_xray
build_config
start_xray
save_active
