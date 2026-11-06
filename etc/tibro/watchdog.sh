#!/bin/sh
# Tibro watchdog: нет данных через туннель -> ближайшая рабочая нода
CONF="/etc/tibro/tibro.conf"
NODES_DIR="/etc/tibro/nodes"
LOG="/var/log/tibro.log"
STATE="/tmp/tibro-wd"
MAX_FAILS=3
BAN_SEC=1800
MAX_TRY=5

log() { echo "[$(date '+%H:%M:%S')] [watchdog] $1" >> "$LOG"; }
mkdir -p "$STATE"

exec 9>"$STATE/run.lock"
flock -n 9 || exit 0
( flock -n 8 ) 8>/var/run/tibro-switch.lock || exit 0

. "$CONF"
nft list table inet tibro >/dev/null 2>&1 || exit 0

if ! pgrep -f "/usr/bin/xray -c" >/dev/null 2>&1; then
    log "xray не запущен при активных правилах TPROXY - перезапуск"
    /etc/init.d/tibro-xray restart >/dev/null 2>&1
    exit 0
fi

tunnel_ok() {
    out=$(nslookup "wd$$$(date +%s).google.com" 127.0.0.1 2>&1)
    echo "$out" | grep -qi "timed out\|no servers could be reached" && return 1
    return 0
}
net_ok() { ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 || ping -c1 -W2 77.88.8.8 >/dev/null 2>&1; }
ban() { echo $(( $(date +%s) + BAN_SEC )) > "$STATE/ban.$1.$2"; }
is_banned() { f="$STATE/ban.$1.$2"; [ -f "$f" ] || return 1; [ "$(date +%s)" -lt "$(cat "$f")" ]; }

list_nodes() {
    awk '
        /"name":/     { i++ }
        /"protocol":/ { split($0, a, "\""); proto = a[4] }
        /"host":/     { split($0, a, "\""); host = a[4] }
        /"port":/     { p = $0; gsub(/[^0-9]/, "", p); print i-1, host, p, proto }
    ' "$1"
}

failover() {
    prov="$ACTIVE_PROVIDER"; cur="$ACTIVE_NODE"
    ban "$prov" "$cur"
    f="$NODES_DIR/$prov.json"
    [ -f "$f" ] || { log "нет файла нод $f"; return 1; }

    list_nodes "$f" > "$STATE/all"
    rm -f "$STATE"/lat.*
    awk '{print $2, $3}' "$STATE/all" | sort -u > "$STATE/uniq"
    n=0
    while read host port; do
        (
            ms=$(curl -s --max-time 10 "http://127.0.0.1/cgi-bin/tibro-api?action=ping&host=$host&port=$port" | grep -o '"ms":[0-9]*' | cut -d: -f2)
            [ -n "$ms" ] && [ "$ms" -lt 9999 ] && echo "$ms" > "$STATE/lat.${host}_${port}"
        ) &
        n=$((n+1))
        [ $((n % 8)) -eq 0 ] && wait
    done < "$STATE/uniq"
    wait

    : > "$STATE/cand"
    while read idx host port proto; do
        [ "$idx" = "$cur" ] && continue
        is_banned "$prov" "$idx" && continue
        lf="$STATE/lat.${host}_${port}"
        [ -f "$lf" ] || continue
        echo "$(cat "$lf") $idx" >> "$STATE/cand"
    done < "$STATE/all"
    sort -n "$STATE/cand" | head -n "$MAX_TRY" > "$STATE/try"

    while read ms idx; do
        log "пробую ноду $prov/$idx (${ms} мс)"
        sh /etc/tibro/switch-node.sh "$prov" "$idx" >/dev/null 2>&1 </dev/null
        sleep 4
        if tunnel_ok || { sleep 4; tunnel_ok; }; then
            log "переключено на $prov/$idx - данные идут"
            echo "$prov:$idx" > "$STATE/key"
            return 0
        fi
        log "нода $prov/$idx тоже не передаёт данные - исключаю на $((BAN_SEC/60)) мин"
        ban "$prov" "$idx"
    done < "$STATE/try"
    log "не нашёл рабочую ноду среди ближайших"
    return 1
}

if [ "$1" = "--force" ]; then
    log "ручной тест: принудительный поиск ближайшей ноды"
    failover
    exit 0
fi

key="$ACTIVE_PROVIDER:$ACTIVE_NODE"
if [ "$(cat "$STATE/key" 2>/dev/null)" != "$key" ]; then
    echo "$key" > "$STATE/key"; echo 0 > "$STATE/fails"; exit 0
fi

if tunnel_ok; then echo 0 > "$STATE/fails"; exit 0; fi

fails=$(( $(cat "$STATE/fails" 2>/dev/null || echo 0) + 1 ))
echo "$fails" > "$STATE/fails"
[ "$fails" -lt "$MAX_FAILS" ] && exit 0
echo 0 > "$STATE/fails"

if ! net_ok; then
    log "внешняя сеть недоступна (8.8.8.8) - смена ноды не поможет"
    exit 0
fi
log "нет данных через $key ($MAX_FAILS проверки подряд) - ищу ближайшую рабочую"
failover
