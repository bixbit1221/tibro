#!/bin/sh
for f in /var/log/tibro.log /var/log/tibro-xray-error.log /var/log/tibro-health.log; do
  [ -f "$f" ] || continue
  s=$(wc -c < "$f")
  if [ "$s" -gt 524288 ]; then
    tail -n 300 "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
  fi
done
