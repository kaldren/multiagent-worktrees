import "server-only";
import postgres from "postgres";

// One pool per dev server process; survives HMR reloads.
const g = globalThis as unknown as { sql?: postgres.Sql };
export const sql = (g.sql ??= postgres(process.env.DATABASE_URL!, { max: 5 }));

export type Feature = {
  id: number;
  title: string;
  status: "todo" | "doing" | "done";
  created_by: string;
  created_at: Date;
};
