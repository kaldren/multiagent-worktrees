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

## One-time setup

```bash
brew install caddy           # already done on this machine
pnpm install
pnpm db:up                   # Postgres 17 in Docker on 127.0.0.1:54329
pnpm db:migrate
pnpm proxy                   # Caddy on :80 (no sudo needed on macOS)
pnpm dev                     # → http://demo.localhost
```

## Working with parallel agents

**Option A: let Claude Code create the worktree**

```bash
claude --worktree feat-a     # creates .claude/worktrees/feat-a on branch worktree-feat-a
                             # and copies .env.local (via .worktreeinclude)
# inside the session: "run pnpm install, then pnpm dev in the background, then build X"
```

**Option B: create it yourself, then start any agent in it**

```bash
pnpm wt new feat-b           # same layout as above + copies .env.local + pnpm install
cd .claude/worktrees/feat-b && claude
```

Either way, `pnpm dev` inside the worktree serves it at `http://<worktree-name>.demo.localhost`.
`CLAUDE.md` tells agents to use that URL and how to behave around the shared DB.

```bash
pnpm wt ls                   # all worktrees + URL + up/stopped
pnpm proxy routes            # what Caddy is currently routing
pnpm url                     # this checkout's URL
pnpm wt rm feat-b            # stop its server, drop its route, remove the worktree (branch kept)
pnpm wt prune                # drop routes left behind by killed dev servers
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
| Rules for agents (background dev server, additive migrations only) | `CLAUDE.md` |

Route files live outside the repo so they work from any worktree, and one Caddy can serve
several projects at once. Give each project its own `APP_DOMAIN` in `.env.local`.

## Caveats of a shared DB
- A destructive migration in one branch breaks every other worktree, so keep migrations additive (see `CLAUDE.md`).
- Two branches adding `002_*.sql` with different contents: whichever runs first wins the name.
  Number migrations at merge time, or use timestamps, if this starts to bite.
- When a branch truly needs its own schema, give that worktree a different `DATABASE_URL`
  (e.g. `createdb demo_feat_x` in the same container) in its `.env.local`.
