#!/usr/bin/env bash
# Shared helpers for dev.sh / wt.sh / proxy.sh / url.sh.
# Identity of "this checkout" is derived from git, so it works the same for
# the main checkout, `pnpm wt new`, `claude --worktree` and plain `git worktree add`.
set -euo pipefail

# Root of the checkout we're in (main or a worktree)
REPO_TOP="$(git rev-parse --show-toplevel)"
# Root of the MAIN checkout (parent of the shared .git dir)
MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"

# One Caddy for all projects on this machine; each running dev server drops a
# tiny site file here. Lives outside every repo so worktrees never write into
# the main checkout.
PROXY_STATE="$HOME/.local/state/localhost-proxy"   # must match the import in caddy/Caddyfile
SITES_DIR="$PROXY_STATE/sites"
CADDYFILE="$REPO_TOP/caddy/Caddyfile"
CADDY_ADMIN="http://localhost:2019"

env_get() { # env_get KEY DEFAULT  (reads .env.local of this checkout)
  local v=""
  [[ -f "$REPO_TOP/.env.local" ]] && v="$(grep -E "^$1=" "$REPO_TOP/.env.local" | tail -1 | cut -d= -f2- || true)"
  echo "${v:-$2}"
}
APP_DOMAIN="$(env_get APP_DOMAIN demo.localhost)"

slugify() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'; }

# name/host for an arbitrary checkout path
name_for() { [[ "$1" == "$MAIN_ROOT" ]] && echo "" || slugify "$(basename "$1")"; }
host_for() { local n; n="$(name_for "$1")"; [[ -z "$n" ]] && echo "$APP_DOMAIN" || echo "$n.$APP_DOMAIN"; }

WORKTREE_NAME="$(name_for "$REPO_TOP")"
HOST="$(host_for "$REPO_TOP")"
BRANCH="$(git branch --show-current 2>/dev/null)"; BRANCH="${BRANCH:-detached}"

site_file() { echo "$SITES_DIR/$1.caddy"; }
site_port() { [[ -f "$(site_file "$1")" ]] && grep -oE '127\.0\.0\.1:[0-9]+' "$(site_file "$1")" | cut -d: -f2 || true; }
port_listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
port_claimed() { grep -qsE "127\.0\.0\.1:$1\b" "$SITES_DIR"/*.caddy; }

# Deterministic per host (so a worktree usually keeps its port across restarts),
# then probe forward until we find one that's neither listening nor claimed.
pick_port() {
  local base p i
  base=$(( $(printf '%s' "$1" | cksum | cut -d' ' -f1) % 900 + 3100 ))
  for ((i = 0; i < 900; i++)); do
    p=$(( (base - 3100 + i) % 900 + 3100 ))
    if ! port_listening "$p" && ! port_claimed "$p"; then echo "$p"; return; fi
  done
  echo "no free port in 3100-3999" >&2; return 1
}

caddy_running() { curl -fsS -o /dev/null "$CADDY_ADMIN/config/" 2>/dev/null; }
caddy_reload() {
  if caddy_running; then
    caddy reload --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1 \
      || echo "⚠️  caddy reload failed — run: caddy reload --config $CADDYFILE" >&2
  else
    echo "⚠️  Caddy isn't running, so http://$HOST won't resolve to this server yet. Start it with: pnpm proxy" >&2
  fi
}

register_site() { # register_site HOST PORT
  mkdir -p "$SITES_DIR"
  printf 'http://%s {\n\treverse_proxy 127.0.0.1:%s\n}\n' "$1" "$2" > "$(site_file "$1")"
  caddy_reload
}
unregister_site() { # unregister_site HOST
  rm -f "$(site_file "$1")"
  caddy_reload
}
