import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { worktreeInfo } from "@/lib/worktree";

async function setName(form: FormData) {
  "use server";
  (await cookies()).set("demo_name", String(form.get("name") ?? ""), { path: "/" });
  revalidatePath("/whoami");
}

export default async function WhoAmI() {
  const wt = worktreeInfo();
  const value = (await cookies()).get("demo_name")?.value;

  return (
    <>
      <h1>Cookie isolation</h1>
      <p className="muted">
        Browsers scope cookies by <em>host</em>, not by port. If every worktree ran on
        <code> localhost:3001</code>, <code>localhost:3002</code>, … they would all share one cookie jar,
        so logging in or out in one worktree would affect the others. Each <code>*.demo.localhost</code>
        subdomain gets its own jar.
      </p>
      <div className="box">
        <p>
          <code>demo_name</code> cookie on <strong>{wt.url || "this host"}</strong>:{" "}
          <strong>{value ?? "(not set)"}</strong>
        </p>
        <form action={setName} className="inline">
          <input type="text" name="name" placeholder="Set a value, then open another worktree's /whoami" />
          <button type="submit">Set cookie</button>
        </form>
      </div>
    </>
  );
}
