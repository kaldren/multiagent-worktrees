#!/usr/bin/env bash
# `pnpm url` — print this checkout's URL (and whether its dev server is up)
source "$(dirname "$0")/lib.sh"
p="$(site_port "$HOST")"
if [[ -n "$p" ]] && port_listening "$p"; then echo "http://$HOST   (running on :$p)"
else echo "http://$HOST   (not running — start with: pnpm dev)"; fi
