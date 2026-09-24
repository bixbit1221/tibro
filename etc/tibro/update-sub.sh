#!/bin/sh
# /etc/tibro/update-sub.sh

CONF="/etc/tibro/tibro.conf"
NODES_DIR="/etc/tibro/nodes"
LOG="/var/log/tibro.log"
TMP="/tmp/tibro_sub"

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

. "$CONF"

mkdir -p "$NODES_DIR"
mkdir -p "$TMP"

# --- base64 декодер на чистом awk (без python3) ---
b64decode() {
    echo "$1" | tr -d '\n\r' | \
    awk 'BEGIN{
        c="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        for(i=0;i<64;i++) v[substr(c,i+1,1)]=i
    }{
        n=split($0,a,"")
        for(i=1;i<=n;i++){
            if(a[i]=="=") break
            b=b*64+v[a[i]]
            bits+=6
            if(bits>=8){
                bits-=8
                printf "%c",int(b/2^bits)
                b=b%(2^bits)
            }
        }
    }'
}

# --- Скачать подписку ---
fetch_sub() {
    local url="$1"
    local ip="$2"
    local out="$3"
    if [ -n "$ip" ]; then
        local host=$(echo "$url" | sed 's|https://||;s|/.*||')
        curl -s --connect-timeout 8 --max-time 20 \
            --resolve "${host}:443:${ip}" \
            -A "xray" "$url" -o "$out"
        if [ ! -s "$out" ]; then
            log "  IP $ip не ответил для $host, пробуем DNS..."
            curl -s --connect-timeout 10 --max-time 30 \
                -A "xray" "$url" -o "$out"
        fi
    else
        curl -s --connect-timeout 10 --max-time 30 \
            -A "xray" "$url" -o "$out"
    fi
}

# --- Общий декодер эмодзи-флагов в имени ноды ---
decode_name() {
    echo "$1" | \
    sed 's/%20/ /g;s/%2B/+/g;\
         s/%F0%9F%87%A9%F0%9F%87%AA/DE/g;\
         s/%F0%9F%87%B7%F0%9F%87%BA/RU/g;\
         s/%F0%9F%87%FA%F0%9F%87%B8/US/g;\
         s/%F0%9F%87%AB%F0%9F%87%AE/FI/g;\
         s/%F0%9F%87%B3%F0%9F%87%B1/NL/g;\
         s/%F0%9F%87%B0%F0%9F%87%BF/KZ/g;\
         s/%F0%9F%87%AA%F0%9F%87%B8/ES/g;\
         s/%F0%9F%87%B8%F0%9F%87%AA/SE/g;\
         s/%F0%9F%87%BA%F0%9F%87%BF/UZ/g;\
         s/%[0-9A-Fa-f][0-9A-Fa-f]//g'
}

is_known_protocol() {
    echo "$1" | grep -qE "^(vless|vmess|trojan|ss|hysteria2)://"
}

# --- Конвертация vless:// и hysteria2:// строк в единый JSON ---
parse_nodes_to_json() {
    local infile="$1"
    local outfile="$2"
    local first=1

    echo '[' > "$outfile"

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | tr -d '\r\n ')
        [ -z "$line" ] && continue

        if echo "$line" | grep -q "^vless://"; then
            local uuid host port params name transport security sni path_v ws_host service authority

            uuid=$(echo "$line"      | sed 's|vless://||;s|@.*||')
            host=$(echo "$line"      | sed 's|vless://[^@]*@||;s|:.*||')
            port=$(echo "$line"      | sed 's|vless://[^@]*@[^:]*:||;s|[?#].*||')
            params=$(echo "$line"    | sed 's|[^?]*?||;s|#.*||')
            name=$(decode_name "$(echo "$line" | sed 's|.*#||')")

            transport=$(echo "$params" | grep -o 'type=[^&]*' | cut -d= -f2)
            security=$(echo "$params"  | grep -o 'security=[^&]*' | cut -d= -f2)
            sni=$(echo "$params"       | grep -o 'sni=[^&]*' | cut -d= -f2)
            path_v=$(echo "$params"    | grep -o 'path=[^&]*' | cut -d= -f2 | sed 's|%2F|/|g')
            ws_host=$(echo "$params"   | grep -o 'host=[^&]*' | cut -d= -f2)
            service=$(echo "$params"   | grep -o 'serviceName=[^&]*' | cut -d= -f2)
            authority=$(echo "$params" | grep -o 'authority=[^&]*' | cut -d= -f2)

            [ -z "$transport" ] && transport="tcp"
            [ -z "$security" ]  && security="tls"
            [ -z "$sni" ]       && sni="$host"
            [ -z "$path_v" ]    && path_v="/"
            [ -z "$ws_host" ]   && ws_host="$host"

            [ "$first" = "1" ] && first=0 || echo ',' >> "$outfile"

            cat >> "$outfile" << EOF
{
  "name": "${name}",
  "protocol": "vless",
  "uuid": "${uuid}",
  "password": "",
  "host": "${host}",
  "port": ${port},
  "transport": "${transport}",
  "security": "${security}",
  "sni": "${sni}",
  "path": "${path_v}",
  "wsHost": "${ws_host}",
  "serviceName": "${service}",
  "authority": "${authority}",
  "up": "",
  "down": ""
}
EOF

        elif echo "$line" | grep -q "^hysteria2://"; then
            local password host port params name sni up down

            password=$(echo "$line" | sed 's|hysteria2://||;s|@.*||' | sed 's/%2B/+/g;s/%2F/\//g;s/%3D/=/g')
            host=$(echo "$line"     | sed 's|hysteria2://[^@]*@||;s|:.*||')
            port=$(echo "$line"     | sed 's|hysteria2://[^@]*@[^:]*:||;s|[?#].*||')
            params=$(echo "$line"   | sed 's|[^?]*?||;s|#.*||')
            name=$(decode_name "$(echo "$line" | sed 's|.*#||')")

            sni=$(echo "$params"  | grep -o 'sni=[^&]*' | cut -d= -f2)
            up=$(echo "$params"   | grep -o 'up=[^&]*' | cut -d= -f2)
            down=$(echo "$params" | grep -o 'down=[^&]*' | cut -d= -f2)

            [ -z "$sni" ] && sni="$host"
            [ -n "$up" ]   && up="${up}mbps"
            [ -n "$down" ] && down="${down}mbps"

            [ "$first" = "1" ] && first=0 || echo ',' >> "$outfile"

            cat >> "$outfile" << EOF
{
  "name": "${name}",
  "protocol": "hysteria2",
  "uuid": "",
  "password": "${password}",
  "host": "${host}",
  "port": ${port},
  "transport": "hysteria",
  "security": "tls",
  "sni": "${sni}",
  "path": "",
  "wsHost": "",
  "serviceName": "",
  "authority": "",
  "up": "${up}",
  "down": "${down}"
}
EOF
        fi
    done < "$infile"

    echo ']' >> "$outfile"
}
# ============================================================
# REMNAWAVE
# ============================================================
log "Обновляем Remnawave..."
fetch_sub "$SUB_REMNAWAVE" "$IP_REMNAWAVE" "$TMP/remnawave_raw"

if [ -s "$TMP/remnawave_raw" ]; then
    first_line=$(head -1 "$TMP/remnawave_raw")
    if is_known_protocol "$first_line"; then
        cp "$TMP/remnawave_raw" "$TMP/remnawave_lines"
    else
        b64decode "$(cat $TMP/remnawave_raw)" > "$TMP/remnawave_lines"
    fi
    parse_nodes_to_json "$TMP/remnawave_lines" "$NODES_DIR/remnawave.json"
    count=$(grep -c '"name"' "$NODES_DIR/remnawave.json" 2>/dev/null || echo 0)
    log "Remnawave: загружено $count нод"
else
    log "ОШИБКА: Remnawave недоступен"
fi

# ============================================================
# HAPP
# ============================================================
log "Обновляем Happ..."
fetch_sub "$SUB_HAPP" "$IP_HAPP" "$TMP/happ_raw"

if [ -s "$TMP/happ_raw" ]; then
    first_line=$(head -1 "$TMP/happ_raw")
    if is_known_protocol "$first_line"; then
        cp "$TMP/happ_raw" "$TMP/happ_lines"
    else
        b64decode "$(cat $TMP/happ_raw)" > "$TMP/happ_lines"
    fi
    parse_nodes_to_json "$TMP/happ_lines" "$NODES_DIR/happ.json"
    count=$(grep -c '"name"' "$NODES_DIR/happ.json" 2>/dev/null || echo 0)
    log "Happ: загружено $count нод"
else
    log "ОШИБКА: Happ недоступен"
fi


# ============================================================
# PROVIDER3
# ============================================================
if [ -n "$SUB_PROVIDER3" ]; then
    log "Обновляем Provider3..."
    fetch_sub "$SUB_PROVIDER3" "$IP_PROVIDER3" "$TMP/provider3_raw"
    if [ -s "$TMP/provider3_raw" ]; then
        first_line=$(head -1 "$TMP/provider3_raw")
        if is_known_protocol "$first_line"; then
            cp "$TMP/provider3_raw" "$TMP/provider3_lines"
        else
            b64decode "$(cat $TMP/provider3_raw)" > "$TMP/provider3_lines"
        fi
        parse_nodes_to_json "$TMP/provider3_lines" "$NODES_DIR/provider3.json"
        count=$(grep -c '"name"' "$NODES_DIR/provider3.json" 2>/dev/null || echo 0)
        log "Provider3: загружено $count нод"
    else
        log "ОШИБКА: Provider3 недоступен"
    fi
fi
rm -rf "$TMP"
log "Обновление подписок завершено"

# Очистка markdown артефактов из JSON
fix_json() {
    local file="$1"
    # Убираем [text](url) -> text
    sed -i 's|\[www\.google\.com\](https://www\.google\.com)|www.google.com|g' "$file"
    sed -i 's|\[gemini\.google\.com\](https://gemini\.google\.com)|gemini.google.com|g' "$file"
    # Универсальная очистка [text](url) -> text
    sed -i 's/\[\([^]]*\)\]([^)]*)/\1/g' "$file"
}

fix_json "$NODES_DIR/happ.json"
fix_json "$NODES_DIR/remnawave.json"
log "JSON очищен от артефактов"
