import { sql, type Feature } from "@/lib/db";
import { worktreeInfo } from "@/lib/worktree";
import { addFeature, advanceFeature } from "./actions";

const hueOf = (name: string) => [...name].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);

export default async function Board() {
  const wt = worktreeInfo();
  const features = await sql<Feature[]>`select * from features order by id desc`;

  return (
    <>
      <h1>Feature board</h1>
      <p className="muted">
        Every worktree has its own code and dev server, but they all share <strong>one database</strong>.
        Add a feature here, then open another worktree&apos;s URL and it&apos;ll be there, tagged with
        the worktree that created it.
      </p>

      <form action={addFeature} className="inline">
        <input type="text" name="title" placeholder={`New feature from ${wt.name}…`} required />
        <button type="submit">Add</button>
      </form>

      <table>
        <thead>
          <tr><th>#</th><th>Feature</th><th>Status</th><th>Created by</th><th /></tr>
        </thead>
        <tbody>
          {features.map((f) => (
            <tr key={f.id}>
              <td>{f.id}</td>
              <td>{f.title}</td>
              <td>{f.status}</td>
              <td>
                <span className="pill" style={{ background: `hsl(${hueOf(f.created_by)} 55% 38%)` }}>
                  {f.created_by}
                </span>
              </td>
              <td>
                <form action={advanceFeature}>
                  <input type="hidden" name="id" value={f.id} />
                  <button className="ghost" type="submit">→</button>
                </form>
              </td>
            </tr>
          ))}
          {features.length === 0 && (
            <tr><td colSpan={5} className="muted">No features yet.</td></tr>
          )}
        </tbody>
      </table>
    </>
  );
}
