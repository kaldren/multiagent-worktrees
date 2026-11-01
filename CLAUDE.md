@AGENTS.md

# Parallel-agent setup (read before running anything)

You may be one of several agents, each in its own git worktree under `.claude/worktrees/<name>`,
all sharing ONE Postgres database and ONE Caddy proxy.

## Running the app — it's already running
- A SessionStart hook (`.claude/settings.json` → `scripts/boot.sh`) has already installed deps,
  started Postgres + Caddy, run migrations and started this checkout's dev server in the background.
  Your session context says the URL. It hot-reloads, so just edit code and reload the URL.
- Your app URL is `http://<worktree-name>.demo.localhost` (main checkout: `http://demo.localhost`).
  Run `pnpm url` to print it. Use that URL for curl / browser checks, never `localhost:3000`.
- Do NOT run `pnpm dev` / `next dev` yourself. If `pnpm url` says "not running", run `pnpm boot`.
  Server output is in `.dev/dev.log`. After adding dependencies, `pnpm halt && pnpm boot` restarts it.
- `pnpm wt ls` shows every worktree, its URL and whether its server is up.
- Don't touch other worktrees' dev servers or `~/.local/state/localhost-proxy/sites/` files you didn't create.

## The database is shared
- Other agents are reading and writing the same DB right now.
- Schema changes: add a NEW file `migrations/NNN_description.sql` (next free number), then `pnpm db:migrate`.
  Migrations must be additive/backward compatible (add tables/columns with defaults; no drops/renames),
  because other worktrees' code still runs against the same schema.
- Never edit an already-applied migration, never `docker compose down -v`, never truncate/drop tables.
- Test data you insert is visible to everyone. Prefix it so it's identifiable.

## If something is down
- Anything down (connection refused, 502, DB refused): run `pnpm boot`. It's idempotent.
