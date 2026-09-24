#!/bin/sh
NODE_FILE="$1"
NODE_IDX="$2"
TPROXY_PORT="7895"

get_field() {
    local field="$1"
    grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[^,}]*" "$NODE_FILE" | \
    sed -n "$((NODE_IDX + 1))p" | \
    sed 's/.*:[[:space:]]*"\(.*\)"/\1/;s/.*:[[:space:]]*\([0-9]*\)/\1/' | \
    tr -d '"'
}

NAME=$(get_field "name")
UUID=$(get_field "uuid")
HOST=$(get_field "host")
PORT=$(get_field "port")
TRANSPORT=$(get_field "transport")
SECURITY=$(get_field "security")
SNI=$(get_field "sni")
PATH_V=$(get_field "path")
WS_HOST=$(get_field "wsHost")
SERVICE=$(get_field "serviceName")
AUTHORITY=$(get_field "authority")
PROTOCOL=$(get_field "protocol")
PASSWORD=$(get_field "password")
UP=$(get_field "up")
DOWN=$(get_field "down")
[ -z "$PROTOCOL" ] && PROTOCOL="vless"

[ -z "$SNI" ]       && SNI="$HOST"
[ -z "$PATH_V" ]    && PATH_V="/"
[ -z "$WS_HOST" ]   && WS_HOST="$HOST"
[ -z "$SECURITY" ]  && SECURITY="none"
[ -z "$TRANSPORT" ] && TRANSPORT="tcp"

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
    echo "ОШИБКА: пустые поля host/port" >&2
    exit 1
fi
if [ "$PROTOCOL" = "vless" ] && [ -z "$UUID" ]; then
    echo "ОШИБКА: пустой uuid для vless" >&2
    exit 1
fi
if [ "$PROTOCOL" = "hysteria2" ] && [ -z "$PASSWORD" ]; then
    echo "ОШИБКА: пустой password для hysteria2" >&2
    exit 1
fi

build_stream() {
    case "$TRANSPORT" in
        ws)
            printf '      "streamSettings": {\n'
            printf '        "network": "ws",\n'
            printf '        "security": "%s",\n' "$SECURITY"
            printf '        "tlsSettings": {\n'
            printf '          "serverName": "%s",\n' "$SNI"
            printf '          "allowInsecure": false,\n'
            printf '          "fingerprint": "chrome",\n'
            printf '          "alpn": ["http/1.1"]\n'
            printf '        },\n'
            printf '        "wsSettings": {\n'
            printf '          "path": "%s",\n' "$PATH_V"
            printf '          "headers": {"Host": "%s"}\n' "$WS_HOST"
            printf '        }\n'
            printf '      }\n'
            ;;
        xhttp)
            printf '      "streamSettings": {\n'
            printf '        "network": "xhttp",\n'
            printf '        "security": "%s",\n' "$SECURITY"
            printf '        "tlsSettings": {\n'
            printf '          "serverName": "%s",\n' "$SNI"
            printf '          "allowInsecure": false,\n'
            printf '          "fingerprint": "chrome",\n'
            printf '          "alpn": ["h2"]\n'
            printf '        },\n'
            printf '        "xhttpSettings": {\n'
            printf '          "path": "%s",\n' "$PATH_V"
            printf '          "host": "%s",\n' "$WS_HOST"
            printf '          "mode": "auto"\n'
            printf '        }\n'
            printf '      }\n'
            ;;
        grpc)
            printf '      "streamSettings": {\n'
            printf '        "network": "grpc",\n'
            printf '        "security": "%s",\n' "$SECURITY"
            printf '        "tlsSettings": {\n'
            printf '          "serverName": "%s",\n' "$SNI"
            printf '          "allowInsecure": false,\n'
            printf '          "fingerprint": "chrome",\n'
            printf '          "alpn": ["h2"]\n'
            printf '        },\n'
            printf '        "grpcSettings": {\n'
            printf '          "serviceName": "%s",\n' "$SERVICE"
            printf '          "authority": "%s"\n' "$AUTHORITY"
            printf '        }\n'
            printf '      }\n'
            ;;
        *)
            printf '      "streamSettings": {\n'
            printf '        "network": "tcp",\n'
            printf '        "security": "%s"\n' "$SECURITY"
            printf '      }\n'
            ;;
    esac
}

printf '{\n'
printf '  "log": {\n'
printf '    "loglevel": "warning",\n'
printf '    "access": "/var/log/tibro-xray.log",\n'
printf '    "error": "/var/log/tibro-xray-error.log"\n'
printf '  },\n'
printf '  "fakedns": {"ipPool": "198.18.0.0/15", "poolSize": 65535},\n'
printf '  "inbounds": [\n'
printf '    {\n'
printf '      "tag": "dns-in",\n'
printf '      "port": 5353,\n'
printf '      "listen": "127.0.0.1",\n'
printf '      "protocol": "dokodemo-door",\n'
printf '      "settings": {"address": "77.88.8.8", "port": 53, "network": "udp", "followRedirect": false}\n'
printf '    },\n'
printf '    {\n'
printf '      "tag": "tproxy-in",\n'
printf '      "port": %s,\n' "$TPROXY_PORT"
printf '      "protocol": "dokodemo-door",\n'
printf '      "settings": {"network": "tcp,udp", "followRedirect": true},\n'
printf '      "sniffing": {"enabled": true, "destOverride": ["fakedns", "http", "tls"], "metadataOnly": false},\n'
printf '      "streamSettings": {"sockopt": {"tproxy": "tproxy"}}\n'
printf '    }\n'
printf '  ],\n'
printf '  "outbounds": [\n'
printf '    {\n'
printf '      "tag": "proxy",\n'
if [ "$PROTOCOL" = "hysteria2" ]; then
    printf '      "protocol": "hysteria",\n'
    printf '      "settings": {"version": 2, "address": "%s", "port": %s},\n' "$HOST" "$PORT"
    printf '      "streamSettings": {\n'
    printf '        "network": "hysteria",\n'
    printf '        "security": "tls",\n'
    printf '        "tlsSettings": {"serverName": "%s", "allowInsecure": false, "alpn": ["h3"]},\n' "$SNI"
    printf '        "hysteriaSettings": {"version": 2, "auth": "%s", "up": "%s", "down": "%s", "udpIdleTimeout": 120}\n' "$PASSWORD" "${UP:-100mbps}" "${DOWN:-100mbps}"
    printf '      }\n'
else
    printf '      "protocol": "vless",\n'
    printf '      "settings": {"vnext": [{"address": "%s", "port": %s, "users": [{"id": "%s", "encryption": "none", "flow": ""}]}]},\n' "$HOST" "$PORT" "$UUID"
    build_stream
fi
printf '    },\n'
printf '    {"tag": "direct", "protocol": "freedom"},\n'
printf '    {"tag": "block", "protocol": "blackhole"}\n'
printf '  ],\n'
printf '  "routing": {\n'
printf '    "domainStrategy": "IPIfNonMatch",\n'
printf '    "rules": [\n'
printf '      {"type": "field", "ip": ["198.18.0.0/15"], "outboundTag": "proxy"},\n'
printf '      {"type": "field", "ip": ["geoip:private"], "outboundTag": "direct"},\n'
printf '      {"type": "field", "network": "tcp,udp", "outboundTag": "proxy"}\n'
printf '    ]\n'
printf '  }\n'
printf '}\n'
