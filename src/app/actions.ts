"use server";
import { revalidatePath } from "next/cache";
import { sql } from "@/lib/db";
import { worktreeInfo } from "@/lib/worktree";

const next = { todo: "doing", doing: "done", done: "todo" } as const;

export async function addFeature(form: FormData) {
  const title = String(form.get("title") ?? "").trim();
  if (!title) return;
  await sql`insert into features (title, created_by) values (${title}, ${worktreeInfo().name})`;
  revalidatePath("/");
}

export async function advanceFeature(form: FormData) {
  const id = Number(form.get("id"));
  const [row] = await sql<{ status: keyof typeof next }[]>`select status from features where id = ${id}`;
  if (!row) return;
  await sql`update features set status = ${next[row.status]} where id = ${id}`;
  revalidatePath("/");
}
