#!/usr/bin/env bash
# `pnpm boot` — bring this checkout fully up, idempotently:
#   deps → Docker/Postgres → migrations → Caddy → dev server (detached) → wait until the URL answers.
# Runs automatically from the SessionStart hook (.claude/settings.json), so starting
# `claude --worktree <name>` is all you need to do. Safe to run any number of times.
source "$(dirname "$0")/lib.sh"
cd "$REPO_TOP"
log() { echo "[boot] $*" >&2; }

# 1. dependencies (pnpm's shared store makes this a few seconds in a fresh worktree)
if [[ ! -d node_modules ]]; then
  log "installing dependencies"; pnpm install --prefer-offline --silent >&2
fi

# 2. shared Postgres (start Docker Desktop if needed)
if ! nc -z 127.0.0.1 54329 2>/dev/null; then
  if ! docker info >/dev/null 2>&1; then
    log "starting Docker Desktop"; open -ga Docker
    for _ in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
  fi
  log "starting Postgres"; docker compose up -d --wait >&2
fi

# 3. migrations (advisory-locked, so concurrent boots are fine)
node --env-file=.env.local scripts/migrate.mts >&2

# 4. shared Caddy proxy
caddy_running || bash scripts/proxy.sh start >&2

# 5. dev server, detached into its own process group so it outlives this script
mkdir -p "$PIDS_DIR" .dev
port="$(site_port "$HOST")"
if [[ -n "$port" ]] && port_listening "$port"; then
  started="already running"
else
  log "starting dev server"
  nohup perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' bash scripts/dev.sh \
    > .dev/dev.log 2>&1 < /dev/null &
  echo $! > "$(pid_file "$HOST")"
  started="started"
  for _ in $(seq 1 60); do
    port="$(site_port "$HOST")"
    [[ -n "$port" ]] && curl -fsS -o /dev/null --max-time 20 "http://$HOST" 2>/dev/null && break
    sleep 0.5
  done
fi

# stdout = context for the agent when run from the SessionStart hook
cat <<MSG
Dev environment for this checkout is up (${started}): http://$HOST  (port ${port:-?}, branch $BRANCH).
Dev server log: $REPO_TOP/.dev/dev.log. Do NOT start another dev server or use localhost:3000; use http://$HOST.
Postgres (shared with other worktrees) and the Caddy proxy are running.
MSG
