import type { NextConfig } from "next";

// Next 16 already allows dev requests from `**.localhost`, so the
// http://<worktree>.demo.localhost hosts work without `allowedDevOrigins`.
// If you switch APP_DOMAIN to something that isn't *.localhost, add it here.
const nextConfig: NextConfig = {};

export default nextConfig;
