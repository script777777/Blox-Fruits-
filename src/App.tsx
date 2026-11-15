import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import "./App.css";

type BypassResponse =
  | {
      ok: true;
      destination: string;
      provider?: string;
      demo?: boolean;
    }
  | {
      ok: false;
      error: string;
    };

function App() {
  const [url, setUrl] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [destination, setDestination] = useState<string | null>(null);
  const [demo, setDemo] = useState(false);
  const [copied, setCopied] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => setReady(true));
    return () => cancelAnimationFrame(id);
  }, []);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setDestination(null);
    setDemo(false);
    setCopied(false);
    setLoading(true);

    try {
      const response = await fetch("/api/bypass", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url: url.trim() }),
      });
      const data = (await response.json()) as BypassResponse;

      if (!data.ok) {
        setError(data.error || "Bypass fehlgeschlagen");
        return;
      }

      setDestination(data.destination);
      setDemo(Boolean(data.demo));
    } catch {
      setError("Netzwerkfehler — bitte später erneut versuchen.");
    } finally {
      setLoading(false);
    }
  }

  async function copyDestination() {
    if (!destination) return;
    try {
      await navigator.clipboard.writeText(destination);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setError("Kopieren nicht möglich");
    }
  }

  return (
    <div className={`page ${ready ? "is-ready" : ""}`}>
      <div className="atmosphere" aria-hidden="true">
        <div className="orb orb-a" />
        <div className="orb orb-b" />
        <div className="grid" />
        <svg className="path-art" viewBox="0 0 1200 800" fill="none">
          <path
            className="path-line"
            d="M80 420 C 220 220, 380 620, 540 360 S 860 180, 1120 400"
            stroke="url(#pathGrad)"
            strokeWidth="2.5"
            strokeLinecap="round"
          />
          <circle className="path-node n1" cx="80" cy="420" r="7" />
          <circle className="path-node n2" cx="540" cy="360" r="7" />
          <circle className="path-node n3" cx="1120" cy="400" r="9" />
          <defs>
            <linearGradient id="pathGrad" x1="80" y1="420" x2="1120" y2="400">
              <stop stopColor="#c8f542" stopOpacity="0.15" />
              <stop offset="0.5" stopColor="#c8f542" stopOpacity="0.55" />
              <stop offset="1" stopColor="#5dffb0" stopOpacity="0.8" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      <header className="topbar">
        <p className="brand">OPENLINK</p>
      </header>

      <main className="hero">
        <p className="brand-mark">OPENLINK</p>
        <h1>Links freischalten.</h1>
        <p className="lede">
          Füge einen geschützten Kurzlink ein — wir holen die Ziel-URL über deine
          API.
        </p>

        <form className="unlock-form" onSubmit={onSubmit}>
          <label className="sr-only" htmlFor="link-input">
            Link einfügen
          </label>
          <input
            id="link-input"
            type="url"
            inputMode="url"
            autoComplete="off"
            spellCheck={false}
            placeholder="https://…"
            value={url}
            onChange={(event) => setUrl(event.target.value)}
            required
          />
          <button type="submit" disabled={loading || !url.trim()}>
            {loading ? "Lädt…" : "Freischalten"}
          </button>
        </form>

        {error ? <p className="status status-error">{error}</p> : null}

        {destination ? (
          <section className="result" aria-live="polite">
            {demo ? (
              <p className="demo-note">
                Demo-Modus: API-URL und Key sind noch nicht gesetzt.
              </p>
            ) : null}
            <p className="result-label">Ziel-URL</p>
            <a
              className="result-link"
              href={destination}
              target="_blank"
              rel="noopener noreferrer"
            >
              {destination}
            </a>
            <div className="result-actions">
              <button type="button" className="ghost" onClick={copyDestination}>
                {copied ? "Kopiert" : "Kopieren"}
              </button>
              <a
                className="ghost linkish"
                href={destination}
                target="_blank"
                rel="noopener noreferrer"
              >
                Öffnen
              </a>
            </div>
          </section>
        ) : null}
      </main>

      <footer className="foot">
        <p>API-Key bleibt serverseitig — nie im Browser.</p>
      </footer>
    </div>
  );
}

export default App;
