// `pnpm db:migrate` — apply migrations/*.sql in filename order.
// The DB is shared by every worktree, so several agents may run this at once:
// a Postgres advisory lock serialises them and schema_migrations makes it idempotent.
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import postgres from "postgres";

const sql = postgres(process.env.DATABASE_URL!, { max: 1, onnotice: () => {} });
const dir = join(import.meta.dirname, "..", "migrations");

try {
  await sql`select pg_advisory_lock(727274)`;
  await sql`create table if not exists schema_migrations (
    name text primary key, applied_at timestamptz not null default now())`;
  const done = new Set((await sql`select name from schema_migrations`).map((r) => r.name));
  const files = (await readdir(dir)).filter((f) => f.endsWith(".sql")).sort();
  let applied = 0;
  for (const f of files) {
    if (done.has(f)) continue;
    await sql.begin(async (tx) => {
      await tx.unsafe(await readFile(join(dir, f), "utf8"));
      await tx`insert into schema_migrations (name) values (${f})`;
    });
    console.log(`applied ${f}`);
    applied++;
  }
  console.log(applied ? `${applied} migration(s) applied` : "database is up to date");
} finally {
  await sql`select pg_advisory_unlock(727274)`.catch(() => {});
  await sql.end();
}
