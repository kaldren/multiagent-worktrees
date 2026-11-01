@AGENTS.md

# Parallel-agent setup (read before running anything)

You may be one of several agents, each in its own git worktree under `.claude/worktrees/<name>`,
all sharing ONE Postgres database and ONE Caddy proxy.

## Running the app
- Start the dev server with `pnpm dev` **as a background process**. Never run `next dev` directly
  and never pass a port: `scripts/dev.sh` picks a free port and registers your URL with Caddy.
- Your app URL is `http://<worktree-name>.demo.localhost` (main checkout: `http://demo.localhost`).
  Run `pnpm url` to print it. Use that URL for curl / browser checks, not `localhost:3000`.
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
- `curl http://demo.localhost` → connection refused: proxy not running → `pnpm proxy`.
- 502 "No dev server is registered": start `pnpm dev` in that worktree.
- DB connection refused: `pnpm db:up`.
