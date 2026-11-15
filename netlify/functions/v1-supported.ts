import type { Config, Context } from "@netlify/functions";
import { handleOptions, supportedCatalog } from "../../src/server/publicApi";

export default async (req: Request, _context: Context) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "GET") {
    return Response.json(
      { status: "failed", result: "Method not allowed" },
      { status: 405 },
    );
  }

  return supportedCatalog();
};

export const config: Config = {
  path: "/api/v1/supported",
  method: ["GET", "OPTIONS"],
};
