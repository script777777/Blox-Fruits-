export type BypassSuccess = {
  ok: true;
  destination: string;
  provider?: string;
  cached?: boolean;
  demo?: boolean;
};

export type BypassError = {
  ok: false;
  error: string;
};

export type BypassResult = BypassSuccess | BypassError;

function readEnv(name: string): string | undefined {
  try {
    const netlifyEnv = (globalThis as { Netlify?: { env: { get(n: string): string | undefined } } })
      .Netlify;
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

function buildUpstreamRequest(targetUrl: string): {
  url: string;
  init: RequestInit;
} {
  const apiUrl = readEnv("BYPASS_API_URL");
  const apiKey = readEnv("BYPASS_API_KEY");
  const authMode = (readEnv("BYPASS_API_AUTH") || "query").toLowerCase();
  const httpMethod = (readEnv("BYPASS_API_METHOD") || "GET").toUpperCase();
  const urlParam = readEnv("BYPASS_API_URL_PARAM") || "url";
  const keyParam = readEnv("BYPASS_API_KEY_PARAM") || "api_key";

  if (!apiUrl) {
    throw new Error("BYPASS_API_URL fehlt");
  }

  const headers: Record<string, string> = {
    Accept: "application/json",
    "User-Agent": "OpenLink/1.0",
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
      init: {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      },
    };
  }

  const endpoint = new URL(apiUrl);
  endpoint.searchParams.set(urlParam, targetUrl);
  if (apiKey && authMode === "query") {
    endpoint.searchParams.set(keyParam, apiKey);
  }

  return {
    url: endpoint.toString(),
    init: {
      method: "GET",
      headers,
    },
  };
}

export async function runBypass(targetUrlRaw: string): Promise<{
  status: number;
  body: BypassResult;
}> {
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

  const apiUrl = readEnv("BYPASS_API_URL");
  const apiKey = readEnv("BYPASS_API_KEY");

  if (!apiUrl || !apiKey) {
    return {
      status: 200,
      body: {
        ok: true,
        destination: "https://example.com/demo-zielseite",
        provider: "demo",
        demo: true,
      },
    };
  }

  try {
    const upstream = buildUpstreamRequest(targetUrl);
    const response = await fetch(upstream.url, upstream.init);
    const text = await response.text();

    let payload: unknown = null;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      payload = null;
    }

    if (!response.ok) {
      const message =
        payload &&
        typeof payload === "object" &&
        typeof (payload as Record<string, unknown>).error === "string"
          ? String((payload as Record<string, unknown>).error)
          : `API-Fehler (${response.status})`;
      return { status: 502, body: { ok: false, error: message } };
    }

    const destination =
      extractDestination(payload) ||
      (isHttpUrl(text.trim()) ? text.trim() : null);

    if (!destination) {
      return {
        status: 502,
        body: {
          ok: false,
          error:
            "Antwort der API enthielt keine Ziel-URL. Prüfe BYPASS_API_* Einstellungen.",
        },
      };
    }

    return {
      status: 200,
      body: {
        ok: true,
        destination,
        provider: readEnv("BYPASS_API_PROVIDER") || "custom",
      },
    };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unbekannter Serverfehler";
    return { status: 500, body: { ok: false, error: message } };
  }
}
