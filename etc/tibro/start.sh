#!/bin/sh
LOG="/var/log/tibro.log"
log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

# Ждём сеть
i=0
while [ $i -lt 30 ]; do
    ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && break
    ping -c1 -W2 77.91.69.174 >/dev/null 2>&1 && break
    sleep 2
    i=$((i+1))
done

sh /etc/tibro/tproxy-stop.sh
pkill -x xray 2>/dev/null
sleep 3
pkill -x xray 2>/dev/null
sleep 2

# Пересобираем конфиг
. /etc/tibro/tibro.conf
sh /etc/tibro/build-config.sh \
    /etc/tibro/nodes/${ACTIVE_PROVIDER}.json \
    $ACTIVE_NODE > /etc/tibro/config.json

ulimit -n 65535
/usr/bin/xray -c /etc/tibro/config.json >> /var/log/tibro-xray.log 2>&1 &
echo $! > /var/run/tibro-xray.pid
sleep 3

PID=$(cat /var/run/tibro-xray.pid)
if kill -0 "$PID" 2>/dev/null; then
    sh /etc/tibro/tproxy.sh
    log "Tibro запущен PID=$PID"
else
    log "ОШИБКА: xray не запустился"
fi

# DNS записи для YouTube через FakeDNS
uci delete dhcp.@dnsmasq[0].address 2>/dev/null
uci add_list dhcp.@dnsmasq[0].address='/youtube.com/198.18.0.1'
uci add_list dhcp.@dnsmasq[0].address='/googlevideo.com/198.18.0.2'
uci add_list dhcp.@dnsmasq[0].address='/ytimg.com/198.18.0.3'
uci add_list dhcp.@dnsmasq[0].address='/googleapis.com/198.18.0.4'
uci add_list dhcp.@dnsmasq[0].address='/googleusercontent.com/198.18.0.5'
uci commit dhcp
/etc/init.d/dnsmasq restart
