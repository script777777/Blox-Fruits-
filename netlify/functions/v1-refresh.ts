import type { Config, Context } from "@netlify/functions";
import {
  getTargetUrl,
  handleOptions,
  publicBypass,
  requireApiKey,
} from "../../src/server/publicApi";

export default async (req: Request, _context: Context) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "GET") {
    return Response.json(
      { status: "failed", result: "Method not allowed" },
      { status: 405 },
    );
  }

  const auth = requireApiKey(req);
  if (!auth.ok) return auth.response;

  return publicBypass(getTargetUrl(req), "refresh");
};

export const config: Config = {
  path: "/api/v1/refresh",
  method: ["GET", "OPTIONS"],
};
