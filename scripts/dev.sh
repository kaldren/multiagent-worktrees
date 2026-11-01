#!/usr/bin/env bash
# `pnpm dev` — start Next on a free port and publish it at http://<worktree>.<APP_DOMAIN>
source "$(dirname "$0")/lib.sh"

existing="$(site_port "$HOST")"
if [[ -n "$existing" ]] && port_listening "$existing"; then
  echo "Already running for this checkout: http://$HOST  (port $existing)"
  exit 0
fi

PORT="$(pick_port "$HOST")"
export PORT WORKTREE_NAME BRANCH
export APP_URL="http://$HOST"

cleanup() { unregister_site "$HOST"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

register_site "$HOST" "$PORT"
cat <<MSG

  ▶ ${WORKTREE_NAME:-main} (branch $BRANCH)
    App URL : $APP_URL
    Direct  : http://localhost:$PORT

MSG
# not exec'd, so the EXIT trap can remove the route when Next stops
"$REPO_TOP/node_modules/.bin/next" dev --port "$PORT" "$@"
