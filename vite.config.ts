import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv, type Plugin } from "vite";
import { runBypass } from "./src/server/bypassCore.ts";
import {
  getTargetUrl,
  publicBypass,
  requireApiKey,
  supportedCatalog,
} from "./src/server/publicApi.ts";

function bypassDevApi(): Plugin {
  return {
    name: "void-syndicate-bypass-dev-api",
    configResolved(config) {
      const env = loadEnv(config.mode, config.root, "");
      for (const [key, value] of Object.entries(env)) {
        if (process.env[key] === undefined) {
          process.env[key] = value;
        }
      }
    },
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const path = req.url?.split("?")[0] || "";

        const send = (status: number, body: unknown, headers: Record<string, string> = {}) => {
          res.statusCode = status;
          res.setHeader("Content-Type", "application/json");
          res.setHeader("Cache-Control", "no-store");
          res.setHeader("Access-Control-Allow-Origin", "*");
          res.setHeader("Access-Control-Allow-Headers", "x-api-key, Content-Type");
          res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
          for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
          res.end(typeof body === "string" ? body : JSON.stringify(body));
        };

        if (path.startsWith("/api/v1/") && req.method === "OPTIONS") {
          send(204, "");
          return;
        }

        if (path === "/api/v1/supported" && req.method === "GET") {
          const response = supportedCatalog();
          send(response.status, await response.text());
          return;
        }

        if (
          (path === "/api/v1/bypass" || path === "/api/v1/refresh") &&
          req.method === "GET"
        ) {
          const headerBag: Record<string, string> = {};
          for (const [k, v] of Object.entries(req.headers)) {
            if (typeof v === "string") headerBag[k] = v;
            else if (Array.isArray(v) && v[0]) headerBag[k] = v[0];
          }
          const fakeReq = new Request(`http://local${req.url}`, {
            method: "GET",
            headers: headerBag,
          });
          const auth = requireApiKey(fakeReq);
          if (!auth.ok) {
            send(auth.response.status, await auth.response.text());
            return;
          }
          const response = await publicBypass(
            getTargetUrl(fakeReq),
            path.endsWith("/refresh") ? "refresh" : "bypass",
          );
          send(response.status, await response.text());
          return;
        }

        if (path !== "/api/bypass") {
          next();
          return;
        }

        if (req.method !== "POST") {
          send(405, { ok: false, error: "Nur POST erlaubt" });
          return;
        }

        const chunks: Buffer[] = [];
        req.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
        req.on("end", async () => {
          try {
            const raw = Buffer.concat(chunks).toString("utf8");
            const parsed = raw
              ? (JSON.parse(raw) as { url?: string; apiKey?: string })
              : {};
            const result = await runBypass(parsed.url || "", {
              apiKey: parsed.apiKey,
            });
            send(result.status, result.body);
          } catch {
            send(400, { ok: false, error: "Ungültiger JSON-Body" });
          }
        });
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), bypassDevApi()],
});
