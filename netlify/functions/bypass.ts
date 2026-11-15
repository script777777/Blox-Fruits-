import type { Config, Context } from "@netlify/functions";
import { runBypass } from "../../src/server/bypassCore";

export default async (req: Request, _context: Context) => {
  if (req.method !== "POST") {
    return Response.json(
      { ok: false, error: "Nur POST erlaubt" },
      { status: 405, headers: { "Cache-Control": "no-store" } },
    );
  }

  let body: { url?: string };
  try {
    body = (await req.json()) as { url?: string };
  } catch {
    return Response.json(
      { ok: false, error: "Ungültiger JSON-Body" },
      { status: 400, headers: { "Cache-Control": "no-store" } },
    );
  }

  const result = await runBypass(body.url || "");
  return Response.json(result.body, {
    status: result.status,
    headers: { "Cache-Control": "no-store" },
  });
};

export const config: Config = {
  path: "/api/bypass",
  method: "POST",
};
