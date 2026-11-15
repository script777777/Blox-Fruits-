import { isHttpUrl, runBypass } from "./bypassCore.js";

export type PublicApiJson =
  | { status: "success"; result: string | unknown; time?: string }
  | { status: "failed"; result: string };

function readEnv(name: string): string | undefined {
  try {
    const netlifyEnv = (
      globalThis as {
        Netlify?: { env: { get(n: string): string | undefined } };
      }
    ).Netlify;
    if (netlifyEnv) {
      const value = netlifyEnv.env.get(name);
      if (value) return value;
    }
  } catch {
    // ignore
  }
  return process.env[name] || undefined;
}

/** Issued customer keys (comma / whitespace / newline separated). */
export function getIssuedKeys(): Set<string> {
  const raw = readEnv("VOID_API_KEYS") || "";
  return new Set(
    raw
      .split(/[\s,]+/)
      .map((k) => k.trim())
      .filter(Boolean),
  );
}

export function corsHeaders(
  extra: Record<string, string> = {},
): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "x-api-key, Content-Type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Cache-Control": "no-store",
    ...extra,
  };
}

export function jsonResponse(
  status: number,
  body: PublicApiJson | Record<string, unknown>,
): Response {
  return Response.json(body, {
    status,
    headers: corsHeaders({ "Content-Type": "application/json" }),
  });
}

export function handleOptions(): Response {
  return new Response(null, { status: 204, headers: corsHeaders() });
}

export function requireApiKey(req: Request): { ok: true; key: string } | { ok: false; response: Response } {
  const key = (req.headers.get("x-api-key") || "").trim();
  if (!key) {
    return {
      ok: false,
      response: jsonResponse(401, {
        status: "failed",
        result: "Missing or invalid x-api-key header",
      }),
    };
  }
  const issued = getIssuedKeys();
  if (!issued.size) {
    return {
      ok: false,
      response: jsonResponse(503, {
        status: "failed",
        result: "API keys are not configured yet",
      }),
    };
  }
  if (!issued.has(key)) {
    return {
      ok: false,
      response: jsonResponse(401, {
        status: "failed",
        result: "Missing or invalid x-api-key header",
      }),
    };
  }
  return { ok: true, key };
}

export function getTargetUrl(req: Request): string {
  const url = new URL(req.url);
  return (url.searchParams.get("url") || "").trim();
}

/**
 * Public bypass: validate customer key, then call upstream with the
 * server master key (BYPASS_API_KEY) — never the customer's Void key.
 */
export async function publicBypass(
  targetUrl: string,
  mode: "bypass" | "refresh" = "bypass",
): Promise<Response> {
  if (!targetUrl) {
    return jsonResponse(400, {
      status: "failed",
      result: "Missing or invalid url parameter",
    });
  }
  if (!isHttpUrl(targetUrl)) {
    return jsonResponse(400, {
      status: "failed",
      result: "Missing or invalid url parameter",
    });
  }

  // Always use server master key for upstream — customer keys are Void-issued only.
  const master = readEnv("BYPASS_API_KEY");
  if (!master) {
    return jsonResponse(503, {
      status: "failed",
      result: "Upstream API is not configured",
    });
  }

  const started = Date.now();
  const result = await runBypass(targetUrl, {
    apiKey: master,
    refresh: mode === "refresh",
  });
  const seconds = ((Date.now() - started) / 1000).toFixed(2);

  if (!result.body.ok) {
    const status =
      result.status === 401 || result.status === 429 ? result.status : result.status >= 500 ? 500 : 400;
    return jsonResponse(status, {
      status: "failed",
      result: result.body.error,
    });
  }

  return jsonResponse(200, {
    status: "success",
    result: result.body.destination,
    time: seconds,
  });
}

export function supportedCatalog(): Response {
  const result = [
    {
      name: "Linkvertise",
      type: "Adlink",
      status: "active",
      domains: [
        "linkvertise.com",
        "link-to.net",
        "link-hub.net",
        "link-target.org",
        "link-target.net",
        "link-center.net",
        "direct-link.net",
      ],
    },
    {
      name: "Lootlabs",
      type: "Adlink",
      status: "active",
      domains: ["loot-link.com", "lootlabs.com", "lootdest.com"],
    },
    {
      name: "Work.ink",
      type: "Adlink",
      status: "active",
      domains: ["work.ink"],
    },
    {
      name: "Platoboost",
      type: "Key system",
      status: "active",
      domains: ["platoboost.com"],
    },
    {
      name: "Admaven",
      type: "Adlink",
      status: "active",
      domains: ["admaz.com", "admaven.com"],
    },
    {
      name: "Rekonise",
      type: "Key system",
      status: "active",
      domains: ["rekonise.com"],
    },
    {
      name: "Shortfly",
      type: "Adlink",
      status: "active",
      domains: ["shortfly.com"],
    },
    {
      name: "Lockr.so",
      type: "Key system",
      status: "active",
      domains: ["lockr.so"],
    },
  ];

  return jsonResponse(200, {
    status: "success",
    result,
  });
}
