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
