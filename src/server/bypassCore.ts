export type BypassSuccess = {
  ok: true;
  destination: string;
  provider?: string;
  cached?: boolean;
  demo?: boolean;
  durationMs?: number;
};

export type BypassError = {
  ok: false;
  error: string;
};

export type BypassResult = BypassSuccess | BypassError;

export type BypassOptions = {
  apiKey?: string;
  /** Use upstream /v1/refresh when the configured URL ends with /bypass */
  refresh?: boolean;
};

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

export function isHttpUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

function extractDestination(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null;
  const data = payload as Record<string, unknown>;

  // Upstream success: { status: "success", result: "https://..." }
  if (data.status === "failed") return null;
  if (data.status === "success" && typeof data.result === "string") {
    return isHttpUrl(data.result) ? data.result : null;
  }

  const candidates = [
    data.destination,
    data.result,
    data.url,
    data.link,
    data.target,
    data.bypassed,
    typeof data.data === "object" && data.data
      ? (data.data as Record<string, unknown>).url
      : undefined,
    typeof data.data === "object" && data.data
      ? (data.data as Record<string, unknown>).destination
      : undefined,
  ];

  for (const candidate of candidates) {
    if (typeof candidate === "string" && isHttpUrl(candidate)) {
      return candidate;
    }
  }

  return null;
}

function extractError(payload: unknown, fallback: string): string {
  if (!payload || typeof payload !== "object") return fallback;
  const data = payload as Record<string, unknown>;
  if (typeof data.result === "string" && data.status === "failed") {
    return data.result;
  }
  if (typeof data.error === "string") return data.error;
  if (typeof data.message === "string") return data.message;
  return fallback;
}

function issuedVoidKeys(): Set<string> {
  const raw = readEnv("VOID_API_KEYS") || "";
  return new Set(
    raw
      .split(/[\s,]+/)
      .map((k) => k.trim())
      .filter(Boolean),
  );
}

/**
 * Pick the key that goes to upstream.
 * Void-issued keys (vs_… / VOID_API_KEYS) must NEVER be forwarded —
 * they only authorize our API; upstream always uses BYPASS_API_KEY.
 */
function resolveUpstreamKey(clientKey?: string): string | undefined {
  const master = readEnv("BYPASS_API_KEY");
  const trimmed = clientKey?.trim();
  if (!trimmed) return master;

  if (trimmed.startsWith("vs_") || issuedVoidKeys().has(trimmed)) {
    return master;
  }

  // User pasted their own upstream provider key
  return trimmed;
}

function humanizeUpstreamError(message: string): string {
  const lower = message.toLowerCase();
  if (lower.includes("invalid linkvertise") || lower.includes("invalid url")) {
    return "This link looks invalid or incomplete. Paste the full URL and try again.";
  }
  if (
    lower.includes("failed to get result") ||
    lower.includes("try again later") ||
    lower.includes("bypass failed")
  ) {
    return "Bypass failed for this link (expired, unsupported, or temporarily unavailable). Try again or use another link.";
  }
  if (lower.includes("provided key is invalid") || lower.includes("unauthorized")) {
    return "API key is invalid. Clear it under “Add API key” or paste a valid key.";
  }
  return message;
}

function resolveApiConfig(
  overrideKey?: string,
  refresh = false,
): {
  apiUrl: string;
  apiKey: string | undefined;
  authMode: string;
  httpMethod: string;
  urlParam: string;
  keyParam: string;
} {
  let apiUrl = readEnv("BYPASS_API_URL") || "https://api.izen.lol/v1/bypass";
  if (refresh) {
    apiUrl =
      readEnv("BYPASS_API_REFRESH_URL") ||
      apiUrl.replace(/\/bypass(?:\?.*)?$/, "/refresh");
  }
  return {
    apiUrl,
    apiKey: resolveUpstreamKey(overrideKey),
    authMode: (readEnv("BYPASS_API_AUTH") || "header").toLowerCase(),
    httpMethod: (readEnv("BYPASS_API_METHOD") || "GET").toUpperCase(),
    urlParam: readEnv("BYPASS_API_URL_PARAM") || "url",
    keyParam: readEnv("BYPASS_API_KEY_PARAM") || "api_key",
  };
}

function buildUpstreamRequest(
  targetUrl: string,
  upstreamKey?: string,
  refresh = false,
): { url: string; init: RequestInit } {
  // upstreamKey is already resolved — pass as override so resolveApiConfig
  // does not re-map empty → master incorrectly when key is intentionally set.
  const { apiUrl, apiKey, authMode, httpMethod, urlParam, keyParam } =
    resolveApiConfig(upstreamKey, refresh);

  const headers: Record<string, string> = {
    Accept: "application/json",
    "User-Agent": "VoidSyndicate/1.0",
  };

  if (apiKey) {
    if (authMode === "bearer") {
      headers.Authorization = `Bearer ${apiKey}`;
    } else if (authMode === "header") {
      headers["x-api-key"] = apiKey;
    } else if (authMode === "authorization") {
      headers.Authorization = apiKey;
    }
  }

  if (httpMethod === "POST") {
    const body: Record<string, string> = { [urlParam]: targetUrl };
    if (apiKey && authMode === "query") {
      body[keyParam] = apiKey;
    }
    headers["Content-Type"] = "application/json";
    return {
      url: apiUrl,
      init: { method: "POST", headers, body: JSON.stringify(body) },
    };
  }

  const endpoint = new URL(apiUrl);
  endpoint.searchParams.set(urlParam, targetUrl);
  if (apiKey && authMode === "query") {
    endpoint.searchParams.set(keyParam, apiKey);
  }

  return {
    url: endpoint.toString(),
    init: { method: "GET", headers },
  };
}

export async function runBypass(
  targetUrlRaw: string,
  options: BypassOptions = {},
): Promise<{ status: number; body: BypassResult }> {
  const targetUrl = targetUrlRaw.trim();
  if (!targetUrl) {
    return { status: 400, body: { ok: false, error: "Bitte eine URL angeben" } };
  }
  if (!isHttpUrl(targetUrl)) {
    return {
      status: 400,
      body: {
        ok: false,
        error: "Nur http:// oder https:// Links sind erlaubt",
      },
    };
  }

  const apiKey = resolveUpstreamKey(options.apiKey);
  const allowDemo = (readEnv("BYPASS_DEMO") || "true").toLowerCase() !== "false";

  if (!apiKey) {
    if (!allowDemo) {
      return {
        status: 401,
        body: {
          ok: false,
          error: "API-Key fehlt. Unter „API-Key hinzufügen“ eintragen.",
        },
      };
    }
    await new Promise((r) => setTimeout(r, 900));
    return {
      status: 200,
      body: {
        ok: true,
        destination: "https://example.com/demo-zielseite",
        provider: "demo",
        demo: true,
        durationMs: 900,
      },
    };
  }

  const started = Date.now();
  try {
    const upstream = buildUpstreamRequest(
      targetUrl,
      apiKey,
      options.refresh,
    );
    const response = await fetch(upstream.url, upstream.init);
    const text = await response.text();
    const durationMs = Date.now() - started;

    let payload: unknown = null;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      payload = null;
    }

    if (!response.ok) {
      return {
        status: response.status === 401 || response.status === 429 ? response.status : 502,
        body: {
          ok: false,
          error: humanizeUpstreamError(
            extractError(payload, `API-Fehler (${response.status})`),
          ),
        },
      };
    }

    if (
      payload &&
      typeof payload === "object" &&
      (payload as Record<string, unknown>).status === "failed"
    ) {
      return {
        status: 502,
        body: {
          ok: false,
          error: humanizeUpstreamError(
            extractError(payload, "Bypass fehlgeschlagen"),
          ),
        },
      };
    }

    const destination =
      extractDestination(payload) ||
      (isHttpUrl(text.trim()) ? text.trim() : null);

    if (!destination) {
      return {
        status: 502,
        body: {
          ok: false,
          error: "Antwort der API enthielt keine Ziel-URL.",
        },
      };
    }

    return {
      status: 200,
      body: {
        ok: true,
        destination,
        provider: readEnv("BYPASS_API_PROVIDER") || "upstream",
        durationMs,
      },
    };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unbekannter Serverfehler";
    return { status: 500, body: { ok: false, error: message } };
  }
}
