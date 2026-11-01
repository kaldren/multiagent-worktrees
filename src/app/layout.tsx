import type { Metadata } from "next";
import Link from "next/link";
import { worktreeInfo } from "@/lib/worktree";
import "./globals.css";

export const dynamic = "force-dynamic";

export async function generateMetadata(): Promise<Metadata> {
  return { title: `[${worktreeInfo().name}] Feature board` };
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const wt = worktreeInfo();
  return (
    <html lang="en">
      <body>
        <div className="banner" style={{ background: `hsl(${wt.hue} 55% 38%)` }} data-worktree={wt.name}>
          <strong>⎇ {wt.name}</strong>
          <span>branch <code>{wt.branch}</code></span>
          <span>port <code>{wt.port}</code></span>
          <span><code>{wt.url}</code></span>
          <nav>
            <Link href="/">Board</Link>
            <Link href="/whoami">Cookies</Link>
          </nav>
        </div>
        <main>{children}</main>
      </body>
    </html>
  );
}
