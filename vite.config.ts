import react from "@vitejs/plugin-react";
import { defineConfig, type Plugin } from "vite";
import { runBypass } from "./src/server/bypassCore.ts";

function bypassDevApi(): Plugin {
  return {
    name: "openlink-bypass-dev-api",
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        if (req.url?.split("?")[0] !== "/api/bypass") {
          next();
          return;
        }

        if (req.method !== "POST") {
          res.statusCode = 405;
          res.setHeader("Content-Type", "application/json");
          res.end(JSON.stringify({ ok: false, error: "Nur POST erlaubt" }));
          return;
        }

        const chunks: Buffer[] = [];
        req.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
        req.on("end", async () => {
          try {
            const raw = Buffer.concat(chunks).toString("utf8");
            const parsed = raw ? (JSON.parse(raw) as { url?: string }) : {};
            const result = await runBypass(parsed.url || "");
            res.statusCode = result.status;
            res.setHeader("Content-Type", "application/json");
            res.setHeader("Cache-Control", "no-store");
            res.end(JSON.stringify(result.body));
          } catch {
            res.statusCode = 400;
            res.setHeader("Content-Type", "application/json");
            res.end(
              JSON.stringify({ ok: false, error: "Ungültiger JSON-Body" }),
            );
          }
        });
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), bypassDevApi()],
});
