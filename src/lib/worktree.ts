// Set by scripts/dev.sh for the running dev server.
export function worktreeInfo() {
  const name = process.env.WORKTREE_NAME || "main";
  return {
    name,
    branch: process.env.BRANCH ?? "?",
    port: process.env.PORT ?? "?",
    url: process.env.APP_URL ?? "",
    // stable colour per worktree so side-by-side tabs are easy to tell apart
    hue: [...name].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7),
  };
}
