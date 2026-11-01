#!/usr/bin/env bash
# `pnpm halt` — stop the dev server that boot.sh started for this checkout.
# Runs from the SessionEnd hook for worktrees (the main checkout's server is left running;
# pass --all to stop it too). Postgres and Caddy are shared, so they're left alone.
source "$(dirname "$0")/lib.sh"
[[ -z "$WORKTREE_NAME" && "${1:-}" != "--all" && "${1:-}" != "--main" ]] && exit 0
pf="$(pid_file "$HOST")"
if [[ -f "$pf" ]]; then
  pid="$(cat "$pf")"
  kill -TERM -- "-$pid" 2>/dev/null || true   # whole group: dev.sh + next; dev.sh's trap drops the route
  for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  rm -f "$pf"
fi
# belt and braces: if the route is still there but nothing listens, drop it
p="$(site_port "$HOST")"
[[ -n "$p" ]] && ! port_listening "$p" && unregister_site "$HOST"
exit 0
