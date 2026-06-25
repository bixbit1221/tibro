#!/bin/sh
TPROXY_PORT="7895"
MARK="0x1"
LOG="/var/log/tibro.log"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log "Применяем TPROXY правила..."

nft delete table inet tibro 2>/dev/null
nft add table inet tibro
nft add chain inet tibro prerouting '{ type filter hook prerouting priority mangle; policy accept; }'

# Исключения ПЕРВЫМИ
nft add rule inet tibro prerouting udp dport 53 return
nft add rule inet tibro prerouting tcp dport 53 return
nft add rule inet tibro prerouting ip daddr 127.0.0.0/8 return
nft add rule inet tibro prerouting ip daddr 192.168.0.0/16 return
nft add rule inet tibro prerouting ip daddr 10.0.0.0/8 return
nft add rule inet tibro prerouting ip daddr 172.16.0.0/12 return
nft add rule inet tibro prerouting ip daddr 224.0.0.0/4 return
nft add rule inet tibro prerouting ip daddr 240.0.0.0/4 return

# TPROXY с явным указанием ip
nft add rule inet tibro prerouting meta l4proto tcp tproxy ip to 127.0.0.1:"$TPROXY_PORT" meta mark set "$MARK"
nft add rule inet tibro prerouting meta l4proto udp tproxy ip to 127.0.0.1:"$TPROXY_PORT" meta mark set "$MARK"

ip rule add fwmark "$MARK" table 100 2>/dev/null
ip route add local default dev lo table 100 2>/dev/null

log "TPROXY правила применены (порт $TPROXY_PORT)"

# Блокировка WebRTC утечек
nft add rule inet tibro prerouting udp dport 3478 drop
nft add rule inet tibro prerouting udp dport 5349 drop
nft add rule inet tibro prerouting tcp dport 3478 drop
nft add rule inet tibro prerouting tcp dport 5349 drop
