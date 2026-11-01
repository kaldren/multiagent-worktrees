#!/usr/bin/env bash
# Claude Code hook entrypoint. Usage: session.sh start|end
# Reads the hook JSON from stdin and acts on the session's cwd (the worktree root for
# `claude --worktree` sessions), regardless of where the hook process itself runs.
set -uo pipefail
input="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
cd "${cwd:-$PWD}" 2>/dev/null || exit 0
top="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0   # not in a git checkout: nothing to do
[[ -f "$top/scripts/boot.sh" ]] || exit 0                       # not this project

case "${1:-}" in
  start)
    # boot failures shouldn't block the session; tell the agent instead
    mkdir -p "$top/.dev"
    bash "$top/scripts/boot.sh" 2>"$top/.dev/boot.log" \
      || echo "Automatic dev environment boot failed — see $top/.dev/boot.log, then run: pnpm boot"
    ;;
  cwd)
    # Claude moved (e.g. EnterWorktree). Only boot if this checkout isn't up yet.
    bash "$top/scripts/url.sh" | grep -q "running on" || bash "$top/scripts/boot.sh" >/dev/null 2>&1
    ;;
  end)
    bash "$top/scripts/halt.sh"
    ;;
esac
exit 0
