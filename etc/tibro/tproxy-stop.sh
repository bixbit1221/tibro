#!/bin/sh
# /etc/tibro/tproxy-stop.sh

MARK="0x1"
LOG="/var/log/tibro.log"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

nft delete table inet tibro 2>/dev/null
ip rule del fwmark "$MARK" table 100 2>/dev/null
ip route del local default dev lo table 100 2>/dev/null

log "TPROXY правила очищены"
