#!/usr/bin/env bash
# `pnpm proxy`        start (or reload) the shared Caddy proxy on :80
# `pnpm proxy stop`   stop it
# `pnpm proxy routes` list registered routes
source "$(dirname "$0")/lib.sh"
mkdir -p "$SITES_DIR"
command -v caddy >/dev/null || { echo "Caddy not installed: brew install caddy" >&2; exit 1; }

case "${1:-start}" in
  start)
    if caddy_running; then
      caddy reload --config "$CADDYFILE" --adapter caddyfile && echo "Caddy reloaded."
    else
      caddy start --config "$CADDYFILE" --adapter caddyfile >"$PROXY_STATE/caddy.log" 2>&1 && echo "Caddy started on :80 (admin $CADDY_ADMIN)."
    fi ;;
  stop) caddy stop ;;
  routes)
    shopt -s nullglob
    for f in "$SITES_DIR"/*.caddy; do
      h="$(basename "$f" .caddy)"; p="$(site_port "$h")"
      printf '%-40s → :%-5s %s\n' "http://$h" "$p" "$(port_listening "$p" && echo up || echo DOWN)"
    done ;;
  *) echo "usage: pnpm proxy [start|stop|routes]" >&2; exit 1 ;;
esac
