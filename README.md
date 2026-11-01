# Parallel agents with worktrees, `*.localhost` domains and one shared DB

A small Next.js "feature board" that shows how to run several coding agents on the same app at
the same time without them clashing over ports, cookies or databases.

```
 browser / agent                    Caddy :80                     dev servers (auto ports)
 ───────────────                    ─────────                     ────────────────────────
 http://demo.localhost        ──►  ─┬─►  127.0.0.1:3941   main checkout ──────┐
 http://feat-a.demo.localhost ──►   ├─►  127.0.0.1:3127   .claude/worktrees/feat-a ─┼─►  Postgres :54329
 http://feat-b.demo.localhost ──►   └─►  127.0.0.1:3655   .claude/worktrees/feat-b ─┘    (one DB, shared)
```

## Why domains rather than ports or extra IPs

| Approach | Problem |
|---|---|
| `localhost:3000/3001/3002…` | Cookies are scoped by **host, not port**, so every worktree shares one cookie jar (auth sessions bleed between them). You also have to remember which port is which. |
| Loopback aliases `127.0.0.2…` | On macOS you need `sudo ifconfig lo0 alias 127.0.0.x` again after every reboot, and IPs are anonymous. |
| **`<name>.demo.localhost`** | `*.localhost` always resolves to 127.0.0.1 (RFC 6761: Chrome, Firefox, Safari, curl), so no `/etc/hosts` or dnsmasq. Each subdomain is its own origin with its own cookies, and the name tells you which worktree you're looking at. |

Caddy maps each hostname to whatever port that worktree's dev server happened to get, so the
port itself stops mattering.

## Usage: the only command is `claude`

```bash
claude --worktree search       # tab 1
claude --worktree dark-mode    # tab 2
claude --worktree tags         # tab 3
```

Each session does all of this on its own (SessionStart hook in `.claude/settings.json` running `scripts/boot.sh`):

1. Claude Code creates `.claude/worktrees/<name>` on branch `worktree-<name>` and copies `.env.local` (`.worktreeinclude`)
2. `pnpm install` if `node_modules` is missing
3. starts Docker Desktop and Postgres if they're down, then runs migrations
4. starts Caddy if it's down
5. starts the worktree's dev server in the background and waits until `http://<name>.demo.localhost` answers
6. tells the agent its URL, so you just describe the feature

When the session ends, a SessionEnd hook stops that worktree's dev server and removes its route.
The main checkout works the same way: `claude` in the repo root brings up `http://demo.localhost`,
and that server keeps running after the session ends.

The only setup is `brew install caddy` and Docker Desktop installed. Everything else boots itself, even after a reboot.

### Manual controls (optional)

```bash
pnpm boot                    # bring this checkout up without Claude (idempotent)
pnpm halt                    # stop this checkout's dev server
pnpm wt ls                   # all worktrees + URL + up/stopped
pnpm wt new <name>           # create a worktree yourself (same layout as claude --worktree)
pnpm wt rm <name> [--force]  # stop server, drop route, remove worktree
pnpm wt prune                # drop routes left behind by killed dev servers
pnpm proxy routes            # what Caddy is currently routing
```

Try it: add a feature on `demo.localhost`, open `feat-a.demo.localhost` and it's there (shared DB).
Set a cookie on `/whoami` in one worktree and it won't show up in another (separate origins).

## How it works

| Piece | File |
|---|---|
| Works out which checkout we're in (main vs worktree), picks a port, writes and removes routes | `scripts/lib.sh` |
| `pnpm dev`: picks a free port (stable per name, 3100–3999), writes `~/.local/state/localhost-proxy/sites/<host>.caddy`, reloads Caddy, runs `next dev`, removes the route on exit | `scripts/dev.sh` |
| Caddy config: imports every site file; unknown hosts get a helpful 502 | `caddy/Caddyfile` |
| Worktree helper mirroring `claude --worktree` (`.claude/worktrees/<name>`, branch `worktree-<name>`, `.worktreeinclude`) | `scripts/wt.sh` |
| Shared DB; compose project name is pinned so every worktree hits the same container | `docker-compose.yml` |
| Migrations: advisory lock + `schema_migrations`, so concurrent agents can run them safely | `scripts/migrate.mts` |
| Hooks: SessionStart → `boot.sh`, SessionEnd → `halt.sh`, CwdChanged (Claude entering a worktree mid-session) → boot if down | `.claude/settings.json`, `scripts/hooks/session.sh` |
| Brings a checkout fully up / stops its server | `scripts/boot.sh`, `scripts/halt.sh` |
| Rules for agents (server is already running, additive migrations only) | `CLAUDE.md` |

Route files live outside the repo so they work from any worktree, and one Caddy can serve
several projects at once. Give each project its own `APP_DOMAIN` in `.env.local`.

## Caveats of a shared DB
- A destructive migration in one branch breaks every other worktree, so keep migrations additive (see `CLAUDE.md`).
- Two branches adding `002_*.sql` with different contents: whichever runs first wins the name.
  Number migrations at merge time, or use timestamps, if this starts to bite.
- When a branch truly needs its own schema, give that worktree a different `DATABASE_URL`
  (e.g. `createdb demo_feat_x` in the same container) in its `.env.local`.
