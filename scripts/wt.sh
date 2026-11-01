#!/usr/bin/env bash
# `pnpm wt new <name>`   create .claude/worktrees/<name> on branch worktree-<name>
#                        (same layout as `claude --worktree <name>`), copy env, install deps
# `pnpm wt ls`           list worktrees with their URL and status
# `pnpm wt rm <name>`    stop its dev server, drop its route, remove the worktree
# `pnpm wt prune`        drop routes whose dev server is gone
source "$(dirname "$0")/lib.sh"
WT_DIR="$MAIN_ROOT/.claude/worktrees"

cmd="${1:-ls}"; shift || true
case "$cmd" in
  new)
    name="$(slugify "${1:?usage: pnpm wt new <name>}")"
    path="$WT_DIR/$name"
    [[ -e "$path" ]] && { echo "$path already exists"; exit 1; }
    git -C "$MAIN_ROOT" worktree add "$path" -b "worktree-$name" HEAD
    # same contract as Claude Code: copy gitignored files listed in .worktreeinclude
    if [[ -f "$MAIN_ROOT/.worktreeinclude" ]]; then
      while IFS= read -r f; do
        [[ -z "$f" || "$f" == \#* ]] && continue
        [[ -e "$MAIN_ROOT/$f" ]] && cp -R "$MAIN_ROOT/$f" "$path/$f"
      done < "$MAIN_ROOT/.worktreeinclude"
    fi
    (cd "$path" && pnpm install --prefer-offline --silent)
    cat <<MSG

  ✔ worktree '$name' ready
    cd $path && claude          # start an agent in it
    pnpm dev                    # → http://$name.$APP_DOMAIN
MSG
    ;;
  ls)
    printf '%-14s %-24s %-38s %s\n' NAME BRANCH URL STATUS
    git -C "$MAIN_ROOT" worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch /{sub("refs/heads/","",$2); print p"\t"$2} /^detached/{print p"\t(detached)"}' |
    while IFS=$'\t' read -r p b; do
      h="$(host_for "$p")"; port="$(site_port "$h")"
      if [[ -n "$port" ]] && port_listening "$port"; then s="up :$port"
      elif [[ -n "$port" ]]; then s="stale route (pnpm wt prune)"
      else s="stopped"; fi
      printf '%-14s %-24s %-38s %s\n' "$(name_for "$p" | sed 's/^$/(main)/')" "$b" "http://$h" "$s"
    done
    ;;
  rm)
    name="$(slugify "${1:?usage: pnpm wt rm <name> [--force]}")"; force="${2:-}"
    path="$WT_DIR/$name"; h="$name.$APP_DOMAIN"
    port="$(site_port "$h")"
    if [[ -n "$port" ]]; then
      pids="$(lsof -t -nP -iTCP:"$port" -sTCP:LISTEN || true)"
      [[ -n "$pids" ]] && kill $pids 2>/dev/null || true
      unregister_site "$h"
    fi
    git -C "$MAIN_ROOT" worktree remove $force "$path"
    echo "Removed $path (branch worktree-$name kept — delete with: git branch -D worktree-$name)"
    ;;
  prune)
    shopt -s nullglob; changed=0
    for f in "$SITES_DIR"/*."$APP_DOMAIN".caddy "$SITES_DIR/$APP_DOMAIN.caddy"; do
      h="$(basename "$f" .caddy)"; p="$(site_port "$h")"
      if ! port_listening "$p"; then rm -f "$f"; echo "pruned $h"; changed=1; fi
    done
    [[ $changed == 1 ]] && caddy_reload || echo "nothing to prune"
    ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
