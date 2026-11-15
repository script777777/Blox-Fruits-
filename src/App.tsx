import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import "./App.css";

type BypassResponse =
  | {
      ok: true;
      destination: string;
      provider?: string;
      demo?: boolean;
      durationMs?: number;
    }
  | { ok: false; error: string };

type Phase = "idle" | "loading" | "success" | "error";

const POPULAR = ["Linkvertise", "Lootlabs", "Work.ink", "Platoboost"];
const SUPPORTS = [
  "Platoboost",
  "Linkvertise",
  "Lootlabs",
  "Admaven",
  "Rekonise",
  "Work.ink",
  "Shortfly",
  "Lockr.so",
];

const FAQ = [
  {
    q: "Ist OPENLINK wirklich kostenlos?",
    a: "Ja. Einzelne Bypass-Anfragen funktionieren ohne Abo. Ein optionaler API-Key schaltet Bulk-Modus frei und überspringt Captchas auf der Original-API.",
  },
  {
    q: "Brauche ich einen API-Key?",
    a: "Für den normalen Single-Modus nicht zwingend. Mit Key (izen.lol) läuft der Bypass ohne Captcha über die Zen-API.",
  },
  {
    q: "Welche Dienste werden unterstützt?",
    a: "u. a. Linkvertise, Platoboost, Lootlabs, Work.ink, Rekonise, Admaven, Shortfly, Lockr.so und viele weitere.",
  },
  {
    q: "Ist das sicher?",
    a: "Dein API-Key wird lokal im Browser gespeichert und nur an unseren Server-Proxy geschickt — nie öffentlich im Frontend-Code hardcodiert.",
  },
  {
    q: "Warum schlägt mein Link fehl?",
    a: "Der Anbieter hat Updates, der Link ist abgelaufen, oder die Upstream-API ist kurz rate-limited. Meist hilft ein erneuter Versuch.",
  },
  {
    q: "Gibt es ein Rate-Limit?",
    a: "Ja — abhängig vom Zen-API-Plan deines Keys. Bei 429 kurz warten und erneut versuchen.",
  },
];

const API_KEY_STORAGE = "openlink_api_key";

function formatDuration(ms: number | undefined, elapsed: number): string {
  const value = ms ?? elapsed;
  if (value >= 1000) return `${(value / 1000).toFixed(2)}s`;
  return `${Math.max(value, 0)} ms`;
}

function LightningIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <path
        fill="currentColor"
        d="M13 2 4 14h7l-1 8 10-14h-7l0-6z"
      />
    </svg>
  );
}

function App() {
  const [url, setUrl] = useState("");
  const [bulkText, setBulkText] = useState("");
  const [mode, setMode] = useState<"single" | "bulk">("single");
  const [apiKey, setApiKey] = useState("");
  const [draftKey, setDraftKey] = useState("");
  const [showKeyModal, setShowKeyModal] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [phase, setPhase] = useState<Phase>("idle");
  const [destination, setDestination] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [demo, setDemo] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [durationMs, setDurationMs] = useState<number | undefined>();
  const [copied, setCopied] = useState(false);
  const [openFaq, setOpenFaq] = useState(0);

  useEffect(() => {
    const saved = localStorage.getItem(API_KEY_STORAGE) || "";
    setApiKey(saved);
    setDraftKey(saved);
  }, []);

  useEffect(() => {
    if (phase !== "loading") return;
    const started = Date.now();
    const id = window.setInterval(() => setElapsed(Date.now() - started), 100);
    return () => window.clearInterval(id);
  }, [phase]);

  const hasKey = Boolean(apiKey.trim());

  const placeholders = useMemo(
    () =>
      mode === "single"
        ? "https://work.ink/..."
        : "Ein Link pro Zeile\nhttps://linkvertise.com/...\nhttps://loot-link.com/...",
    [mode],
  );

  function saveApiKey() {
    const next = draftKey.trim();
    setApiKey(next);
    if (next) localStorage.setItem(API_KEY_STORAGE, next);
    else localStorage.removeItem(API_KEY_STORAGE);
    setShowKeyModal(false);
  }

  async function runOne(target: string) {
    const response = await fetch("/api/bypass", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        url: target,
        apiKey: apiKey.trim() || undefined,
      }),
    });
    return (await response.json()) as BypassResponse;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setDestination(null);
    setDemo(false);
    setCopied(false);
    setDurationMs(undefined);
    setElapsed(0);
    setPhase("loading");

    try {
      if (mode === "bulk") {
        const lines = bulkText
          .split(/\n+/)
          .map((line) => line.trim())
          .filter(Boolean);
        if (!lines.length) {
          setPhase("error");
          setError("Bitte mindestens eine URL eingeben");
          return;
        }
        if (!hasKey) {
          setPhase("error");
          setError("Bulk-Modus braucht einen API-Key.");
          return;
        }
        const first = await runOne(lines[0]);
        if (!first.ok) {
          setPhase("error");
          setError(first.error);
          return;
        }
        setDestination(first.destination);
        setDemo(Boolean(first.demo));
        setDurationMs(first.durationMs);
        setPhase("success");
        return;
      }

      const data = await runOne(url.trim());
      if (!data.ok) {
        setPhase("error");
        setError(data.error);
        return;
      }
      setDestination(data.destination);
      setDemo(Boolean(data.demo));
      setDurationMs(data.durationMs);
      setPhase("success");
    } catch {
      setPhase("error");
      setError("Netzwerkfehler — bitte später erneut versuchen.");
    }
  }

  async function copyText(value: string) {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
      } else {
        const area = document.createElement("textarea");
        area.value = value;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.left = "-9999px";
        document.body.appendChild(area);
        area.select();
        document.execCommand("copy");
        document.body.removeChild(area);
      }
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1600);
    } catch {
      setError("Kopieren nicht möglich");
    }
  }

  function resetResult() {
    setPhase("idle");
    setDestination(null);
    setError(null);
    setDemo(false);
  }

  return (
    <div className="site">
      <header className="top">
        <a className="logo" href="#top">
          <span className="logo-mark">
            <LightningIcon />
          </span>
          <span>openlink.app</span>
        </a>
        <div className="top-actions">
          <button
            type="button"
            className="icon-btn"
            aria-label="API-Key"
            onClick={() => {
              setDraftKey(apiKey);
              setShowKeyModal(true);
            }}
          >
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
              <rect x="5" y="11" width="14" height="10" rx="2" />
              <path d="M8 11V8a4 4 0 0 1 8 0v3" />
            </svg>
            {hasKey ? <span className="dot" /> : null}
          </button>
          <a className="icon-btn" href="https://discord.com" target="_blank" rel="noreferrer" aria-label="Discord">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
              <path d="M19.3 5.2A16 16 0 0 0 15.2 4l-.3.6c1.5.4 2.3 1 3 1.7-1.3-.6-2.6-1-4-1.2a13 13 0 0 0-4 0c-1.4.2-2.7.6-4 1.2.7-.7 1.6-1.3 3-1.7L8.6 4A16 16 0 0 0 4.5 5.2C2.3 8.6 1.7 11.9 2 15.2a16 16 0 0 0 5 2.5l.7-1.1a10 10 0 0 1-1.6-.8l.4-.3c3 1.4 6.3 1.4 9.2 0l.4.3c-.5.3-1 .6-1.6.8l.7 1.1a16 16 0 0 0 5-2.5c.4-3.8-.5-7.1-2.4-10zm-10 8.2c-.9 0-1.6-.8-1.6-1.8s.7-1.8 1.6-1.8 1.7.8 1.6 1.8-.7 1.8-1.6 1.8zm5.4 0c-.9 0-1.6-.8-1.6-1.8s.7-1.8 1.6-1.8 1.7.8 1.6 1.8-.7 1.8-1.6 1.8z" />
            </svg>
          </a>
          <button
            type="button"
            className="icon-btn"
            aria-label="Menü"
            onClick={() => setMenuOpen((v) => !v)}
          >
            {menuOpen ? (
              <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" strokeWidth="2" fill="none">
                <path d="M6 6l12 12M18 6 6 18" />
              </svg>
            ) : (
              <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" strokeWidth="2" fill="none">
                <path d="M4 7h16M4 12h16M4 17h16" />
              </svg>
            )}
          </button>
        </div>
      </header>

      {menuOpen ? (
        <div className="menu-panel">
          <a href="#top" onClick={() => setMenuOpen(false)}>
            Home
          </a>
          <a href="#how" onClick={() => setMenuOpen(false)}>
            How it works
          </a>
          <a href="#why" onClick={() => setMenuOpen(false)}>
            Why us
          </a>
          <a href="#faq" onClick={() => setMenuOpen(false)}>
            FAQ
          </a>
          <button
            type="button"
            className="menu-chip"
            onClick={() => {
              setMenuOpen(false);
              setDraftKey(apiKey);
              setShowKeyModal(true);
            }}
          >
            API key
          </button>
        </div>
      ) : null}

      <main id="top" className="main">
        <section className="hero">
          <p className="pill">
            <span className="pill-dot" />
            Fast, free link bypassing
          </p>
          <h1>
            Skip the wait. <span>Get to the link.</span>
          </h1>
          <p className="lede">
            Paste any supported link and let OpenLink take care of the redirects,
            timers, and clutter.
          </p>
          <ul className="checks">
            <li>100+ services</li>
            <li>No surveys</li>
            <li>No installation</li>
          </ul>
        </section>

        <section className="bypass-card" aria-live="polite">
          {phase === "loading" ? (
            <div className="state-panel">
              <div className="state-head">
                <div className="spinner" />
                <div>
                  <h2>Bypassing...</h2>
                  <p>Processing your link</p>
                </div>
                <span className="timer">{formatDuration(undefined, elapsed)}</span>
              </div>
              <div className="skeleton">
                <div className="sk sk-lg" />
                <div className="sk sk-md" />
                <div className="sk-row">
                  <div className="sk sk-box" />
                  <div className="sk sk-box" />
                </div>
              </div>
            </div>
          ) : null}

          {phase === "success" && destination ? (
            <div className="state-panel success">
              <div className="state-head">
                <div className="check-badge">✓</div>
                <div>
                  <h2>Bypass complete</h2>
                  <p>
                    Close anytime • {formatDuration(durationMs, elapsed)}
                    {demo ? " • Demo" : ""}
                  </p>
                </div>
                <button type="button" className="ghost-btn" onClick={resetResult}>
                  Close
                </button>
              </div>
              <div className="result-box">{destination}</div>
              <div className="result-actions">
                <a
                  className="primary-btn"
                  href={destination}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Open Link
                </a>
                <button
                  type="button"
                  className="secondary-btn"
                  onClick={() => copyText(destination)}
                >
                  {copied ? "Copied" : "Copy"}
                </button>
              </div>
              <button
                type="button"
                className="text-link"
                onClick={() => copyText(url || destination)}
              >
                Copy original URL
              </button>
            </div>
          ) : null}

          {phase === "idle" || phase === "error" ? (
            <>
              <div className="card-head">
                <div>
                  <h2>Enter your link</h2>
                  <p>We'll bypass it for you and get you to your destination or result.</p>
                </div>
              </div>

              <div className="toolbar">
                <div className="mode-toggle" role="tablist">
                  <button
                    type="button"
                    className={mode === "single" ? "active" : ""}
                    onClick={() => setMode("single")}
                  >
                    Single
                  </button>
                  <button
                    type="button"
                    className={mode === "bulk" ? "active" : ""}
                    onClick={() => setMode("bulk")}
                  >
                    Bulk
                  </button>
                </div>
                <button
                  type="button"
                  className="text-link"
                  onClick={() => {
                    setDraftKey(apiKey);
                    setShowKeyModal(true);
                  }}
                >
                  {hasKey ? "API key saved" : "Add API key"}
                </button>
              </div>

              <form onSubmit={onSubmit} className="bypass-form">
                {mode === "single" ? (
                  <label className="field">
                    <span className="field-icon" aria-hidden="true">
                      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.8">
                        <path d="M10 14a5 5 0 0 0 7.1 0l2.1-2.1a5 5 0 0 0-7.1-7.1L11 5.9" />
                        <path d="M14 10a5 5 0 0 0-7.1 0L4.8 12.1a5 5 0 0 0 7.1 7.1L13 18.1" />
                      </svg>
                    </span>
                    <input
                      type="url"
                      required
                      placeholder={placeholders}
                      value={url}
                      onChange={(e) => setUrl(e.target.value)}
                      autoComplete="off"
                      spellCheck={false}
                    />
                  </label>
                ) : (
                  <textarea
                    className="bulk-field"
                    required
                    rows={5}
                    placeholder={placeholders}
                    value={bulkText}
                    onChange={(e) => setBulkText(e.target.value)}
                    spellCheck={false}
                  />
                )}
                {error ? <p className="error">{error}</p> : null}
                <button type="submit" className="primary-btn wide">
                  Bypass <span aria-hidden="true">→</span>
                </button>
              </form>

              <div className="popular">
                <div className="popular-top">
                  <span>POPULAR</span>
                  <a href="#why">All services →</a>
                </div>
                <div className="tags">
                  {POPULAR.map((item) => (
                    <span key={item}>{item}</span>
                  ))}
                </div>
              </div>
            </>
          ) : null}
        </section>

        <section className="stats">
          <div>
            <strong>46.400.000+</strong>
            <span>Links bypassed</span>
          </div>
          <div>
            <strong>100+</strong>
            <span>Services</span>
          </div>
          <div>
            <strong>1 year</strong>
            <span>Of service</span>
          </div>
        </section>

        <section id="how" className="section">
          <p className="eyebrow">Getting started</p>
          <h2>How it works</h2>
          <div className="steps">
            <article>
              <div className="step-meta">
                <span className="step-num">01</span>
                <span>step</span>
              </div>
              <h3>Paste your link</h3>
              <p>
                Drop any Linkvertise, Platoboost, Loot-Link, or supported URL into
                the input. Bulk mode available with an API key.
              </p>
            </article>
            <article>
              <div className="step-meta">
                <span className="step-num">02</span>
                <span>step</span>
              </div>
              <h3>Verify captcha</h3>
              <p>
                On zen.lol itself a captcha prevents abuse. With your API key
                OpenLink talks to the API directly and skips that step.
              </p>
            </article>
            <article>
              <div className="step-meta">
                <span className="step-num">03</span>
                <span>step</span>
              </div>
              <h3>Get results</h3>
              <p>Receive your bypassed link instantly. Copy or open with one click.</p>
            </article>
          </div>
        </section>

        <section id="why" className="section">
          <p className="eyebrow">Why us</p>
          <h2>Why choose OpenLink?</h2>
          <div className="feature">
            <div className="feature-icon">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
                <rect x="4" y="8" width="16" height="12" rx="2" />
                <path d="M12 8V4M8 8c0-2 1.5-3.5 4-3.5S16 6 16 8" />
                <path d="M12 8v12" />
              </svg>
            </div>
            <h3>
              100% Free <s>$8/mo</s>
            </h3>
            <p>
              No paywalls, no premium tiers, no rate-limit walls on the free UI.
              Connect your Zen API key for captcha-free bypasses.
            </p>
            <p className="supports-label">Supports</p>
            <div className="tags">
              {SUPPORTS.map((item) => (
                <span key={item}>{item}</span>
              ))}
              <span className="more">+90 more</span>
            </div>
          </div>
          <div className="feature-grid">
            <article className="feature">
              <div className="feature-icon">
                <LightningIcon />
              </div>
              <h3>Lightning fast</h3>
              <p>Optimized pipeline delivers results in seconds across 100+ services.</p>
            </article>
            <article className="feature">
              <div className="feature-icon">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <path d="M12 3 5 6v6c0 4.5 3 7.5 7 9 4-1.5 7-4.5 7-9V6l-7-3z" />
                </svg>
              </div>
              <h3>Secure & private</h3>
              <p>
                API keys stay in your browser storage and our server proxy — never
                baked into public frontend code.
              </p>
            </article>
          </div>
        </section>

        <section id="faq" className="section">
          <p className="eyebrow">Questions</p>
          <h2>Frequently asked</h2>
          <div className="faq">
            {FAQ.map((item, index) => {
              const open = openFaq === index;
              return (
                <div key={item.q} className={`faq-item ${open ? "open" : ""}`}>
                  <button
                    type="button"
                    onClick={() => setOpenFaq(open ? -1 : index)}
                  >
                    <span>{item.q}</span>
                    <span className="faq-toggle">{open ? "×" : "+"}</span>
                  </button>
                  {open ? <p>{item.a}</p> : null}
                </div>
              );
            })}
          </div>
          <div className="contact-block">
            <p>Still have a question? We're happy to help.</p>
            <a className="outline-btn" href="mailto:hello@openlink.app">
              Contact us ↗
            </a>
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="footer-brand">
          <div className="logo">
            <span className="logo-mark">
              <LightningIcon />
            </span>
            <span>openlink.app</span>
          </div>
          <p>
            Free bypasser for Linkvertise, Work.ink, Lootlabs, Admaven and key
            systems. Powered by the Zen API.
          </p>
        </div>
        <div className="footer-cols">
          <div>
            <h4>Product</h4>
            <a href="#top">Home</a>
            <a href="#why">Supported</a>
            <a href="#faq">API</a>
          </div>
          <div>
            <h4>Resources</h4>
            <a href="https://api.izen.lol/docs" target="_blank" rel="noreferrer">
              Docs
            </a>
            <a href="https://izen.lol/" target="_blank" rel="noreferrer">
              Zen
            </a>
          </div>
          <div>
            <h4>Legal</h4>
            <a href="#faq">Terms</a>
            <a href="#faq">Privacy</a>
            <a href="mailto:hello@openlink.app">Contact</a>
          </div>
        </div>
        <div className="footer-bottom">
          <span className="status">
            <i /> Operational
          </span>
          <span>openlink.app © 2026</span>
        </div>
      </footer>

      {showKeyModal ? (
        <div className="modal-backdrop" role="presentation" onClick={() => setShowKeyModal(false)}>
          <div
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-label="API key"
            onClick={(e) => e.stopPropagation()}
          >
            <h3>API key</h3>
            <p>
              Von{" "}
              <a href="https://api.izen.lol/docs" target="_blank" rel="noreferrer">
                api.izen.lol
              </a>{" "}
              — wird lokal gespeichert und als <code>x-api-key</code> gesendet.
            </p>
            <input
              type="password"
              value={draftKey}
              onChange={(e) => setDraftKey(e.target.value)}
              placeholder="izen_..."
              autoComplete="off"
            />
            <div className="modal-actions">
              <button type="button" className="secondary-btn" onClick={() => setShowKeyModal(false)}>
                Cancel
              </button>
              <button type="button" className="primary-btn" onClick={saveApiKey}>
                Save
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

export default App;
