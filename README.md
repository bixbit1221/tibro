# Tibro VPN

Xray-based VPN management panel for OpenWrt with LuCI web interface.

## Features
- Multi-provider subscription support (Remnawave, Happ format, and custom providers)
- Web UI for switching nodes, viewing ping/latency, and updating subscriptions
- FakeDNS-based traffic routing for common streaming services
- TPROXY-based transparent proxying

## Installation
1. Copy the files to the corresponding paths on your OpenWrt router (preserving directory structure).
2. Copy `etc/tibro/tibro.conf.example` to `etc/tibro/tibro.conf` and fill in your actual subscription URLs.
3. Enable and start the service:
   `/etc/init.d/tibro-xray enable`
   `/etc/init.d/tibro-xray start`
4. Access the web UI via LuCI: Services -> Tibro VPN.

## Requirements
- OpenWrt with LuCI (JS-based views, LuCI 19+)
- xray-core installed at /usr/bin/xray
- curl, awk (busybox is fine)

## Security note
Never commit your real `tibro.conf` (with actual subscription URLs/credentials) to a public repository. Use `tibro.conf.example` as a template only.

## Enabling the watchdog and log trimming

```sh
chmod +x /etc/tibro/watchdog.sh /etc/tibro/logtrim.sh
(crontab -l 2>/dev/null; echo '* * * * * /etc/tibro/watchdog.sh >/dev/null 2>&1'; echo '0 * * * * /etc/tibro/logtrim.sh'; echo '0 */6 * * * sh /etc/tibro/update-sub.sh >> /var/log/tibro.log 2>&1') | crontab -
/etc/init.d/cron restart
```

## Reliability

- **Node switching is serialized.** `switch-node.sh` takes a lock (BusyBox `flock`) and delegates the (re)start to procd (`/etc/init.d/tibro-xray restart`), so quick consecutive switches can no longer leave two xray processes behind.
- **Fast start.** The init script waits for the WAN interface via `ubus` instead of pinging an external host (which may be blocked), so a restart takes seconds.

## Auto-failover watchdog

`etc/tibro/watchdog.sh` runs from cron once a minute and keeps the router online when the active node stops passing data.

1. It resolves a random name through the local resolver (dnsmasq -> xray DNS inbound -> active node). A timeout means the tunnel is not passing data.
2. After 3 failed checks in a row it first makes sure the plain internet works (ping 8.8.8.8 / 77.88.8.8). If the uplink itself is down, switching nodes would not help, so it does nothing.
3. Otherwise it measures the latency of the active provider's nodes (via the `tibro-api` ping), tries the closest ones in order (up to 5) and after each switch checks that DNS works through the tunnel again.
4. A node that failed is excluded for 30 minutes (state lives in `/tmp/tibro-wd`, so it resets on reboot).
5. If xray is not running while the TPROXY rules are loaded (clients would have no internet at all), it restarts xray.

It stays out of the way when Tibro was stopped on purpose (no nft table) or while a switch is already running.

Manual test (switches to the closest working node; internet may drop for a few minutes if several nodes fail in a row):

```sh
sh /etc/tibro/watchdog.sh --force
grep watchdog /var/log/tibro.log | tail
```

Tunables at the top of the script: `MAX_FAILS`, `BAN_SEC`, `MAX_TRY`.

Limitation: the health check is DNS through the tunnel (UDP). A node that resolves names but breaks plain TCP traffic would not be detected.

## Log maintenance and memory

On OpenWrt `/var/log` lives in RAM. The xray access log is therefore disabled (`"access": "none"` in the generated config): on a 256 MB router it grew to about 44 MB and contributed to xray being killed by the kernel OOM killer. Errors still go to `/var/log/tibro-xray-error.log`.

`etc/tibro/logtrim.sh` (hourly via cron) keeps `tibro.log`, `tibro-xray-error.log` and `tibro-health.log` small: a file above 512 KB is cut to its last 300 lines.

## Ping and node types

- Node ping resolves hostnames with DNS-over-HTTPS (dns.google, pinned to 8.8.8.8), so it does not depend on the active tunnel and is not fooled by tampered plain DNS. Answers pointing to loopback count as unreachable. If the TCP connect fails, ICMP is used as a fallback.
- Supported node types: VLESS (tcp, ws, grpc, xhttp) and Hysteria2 (shown with the `hysteria` badge). Hysteria2 runs over UDP, so a TCP/ICMP ping says little about whether it works; the watchdog's DNS-through-tunnel check is the reliable signal.

