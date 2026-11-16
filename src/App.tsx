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
  | { ok: false; error: string; apiResponse?: string };

type Phase = "idle" | "loading" | "success" | "error";
type View = "home" | "contact" | "bot" | "pricing" | "docs" | "extension";

const DISCORD_INVITE = "https://discord.gg/Rn9Bh7CwAr";
const BOT_INVITE =
  "https://discord.com/oauth2/authorize?client_id=1568604487470420068&permissions=8&integration_type=0&scope=bot";
const CONTACT_EMAIL = "contact@voidsyndicate.app";

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
    q: "Ist Void Syndicate wirklich kostenlos?",
    a: "Ja. Einzelne Bypass-Anfragen auf der Website sind gratis und ohne Captcha. Ein API-Key schaltet Bulk-Modus und die öffentliche API frei.",
  },
  {
    q: "Brauche ich einen API-Key?",
    a: "Für Single-Bypass auf der Website nein. Der Key ist für Bulk, Bots und eigene Apps über unsere API.",
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
    q: "Gibt es ein API-Limit / Plan?",
    a: "Die Website hat kein Limit. Für die öffentliche API siehe Pricing — Monthly ist unlimited, Pay-as-you-go zählt nur erfolgreiche Requests.",
  },
  {
    q: "Kann ich die API in meiner App nutzen?",
    a: "Ja. Unter Docs findest du die Endpoints. Keys bekommst du über Discord (Buy auf der Pricing-Seite).",
  },
];

const PLANS = [
  {
    id: "payg",
    name: "Pay-as-you-go",
    price: "$1",
    unit: "/ 1,000 requests",
    blurb: "Flexible credits. Only successful bypasses count toward your usage.",
    features: [
      "Only counts successful bypasses",
      "Cache results are not counted",
      "No expiry on unused credits",
      "Full bypass catalog",
    ],
    cta: "Buy credits",
    best: "Best for testing or variable traffic",
    recommended: false,
  },
  {
    id: "monthly",
    name: "Monthly",
    price: "$8",
    unit: "/ 30 days",
    blurb: "Unlimited requests with always-on access. Predictable billing for production apps.",
    features: [
      "Unlimited bypass requests",
      "No daily caps",
      "24/7 API availability",
      "Full bypass catalog",
      "Priority support on Discord",
    ],
    cta: "Get monthly access",
    best: "Best for steady production traffic",
    recommended: true,
  },
];

const API_KEY_STORAGE = "void_syndicate_api_key";

function formatDuration(ms: number | undefined, elapsed: number): string {
  const value = ms ?? elapsed;
  if (value >= 1000) return `${(value / 1000).toFixed(2)}s`;
  return `${Math.max(value, 0)} ms`;
}

function LightningIcon({ size = 18 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
      <path fill="currentColor" d="M13 2 4 14h7l-1 8 10-14h-7l0-6z" />
    </svg>
  );
}

function DiscordIcon({ size = 18 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="currentColor" aria-hidden="true">
      <path d="M19.3 5.2A16 16 0 0 0 15.2 4l-.3.6c1.5.4 2.3 1 3 1.7-1.3-.6-2.6-1-4-1.2a13 13 0 0 0-4 0c-1.4.2-2.7.6-4 1.2.7-.7 1.6-1.3 3-1.7L8.6 4A16 16 0 0 0 4.5 5.2C2.3 8.6 1.7 11.9 2 15.2a16 16 0 0 0 5 2.5l.7-1.1a10 10 0 0 1-1.6-.8l.4-.3c3 1.4 6.3 1.4 9.2 0l.4.3c-.5.3-1 .6-1.6.8l.7 1.1a16 16 0 0 0 5-2.5c.4-3.8-.5-7.1-2.4-10zm-10 8.2c-.9 0-1.6-.8-1.6-1.8s.7-1.8 1.6-1.8 1.7.8 1.6 1.8-.7 1.8-1.6 1.8zm5.4 0c-.9 0-1.6-.8-1.6-1.8s.7-1.8 1.6-1.8 1.7.8 1.6 1.8-.7 1.8-1.6 1.8z" />
    </svg>
  );
}

function App() {
  const [view, setView] = useState<View>("home");
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
  const [apiResponse, setApiResponse] = useState<string | null>(null);
  const [demo, setDemo] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [durationMs, setDurationMs] = useState<number | undefined>();
  const [copied, setCopied] = useState(false);
  const [pasted, setPasted] = useState(false);
  const [pasteError, setPasteError] = useState<string | null>(null);
  const [canShare, setCanShare] = useState(false);
  const [openFaq, setOpenFaq] = useState(0);

  useEffect(() => {
    const saved = localStorage.getItem(API_KEY_STORAGE) || "";
    setApiKey(saved);
    setDraftKey(saved);
    setCanShare(typeof navigator !== "undefined" && typeof navigator.share === "function");
  }, []);

  useEffect(() => {
    if (phase !== "loading") return;
    const started = Date.now();
    const id = window.setInterval(() => setElapsed(Date.now() - started), 100);
    return () => window.clearInterval(id);
  }, [phase]);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [view]);

  const hasKey = Boolean(apiKey.trim());

  const placeholders = useMemo(
    () =>
      mode === "single"
        ? "https://linkvertise.com/..."
        : "One link per line\nhttps://linkvertise.com/...\nhttps://loot-link.com/...",
    [mode],
  );

  function goHome() {
    setView("home");
    setMenuOpen(false);
  }

  function goContact() {
    setView("contact");
    setMenuOpen(false);
  }

  function goBot() {
    setView("bot");
    setMenuOpen(false);
  }

  function goPricing() {
    setView("pricing");
    setMenuOpen(false);
  }

  function goDocs() {
    setView("docs");
    setMenuOpen(false);
  }

  function goExtension() {
    setView("extension");
    setMenuOpen(false);
  }

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
    setApiResponse(null);
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
          setError("Please enter at least one URL");
          return;
        }
        if (!hasKey) {
          setPhase("error");
          setError("Bulk mode needs an API key.");
          return;
        }
        const first = await runOne(lines[0]);
        if (!first.ok) {
          setPhase("error");
          setError(first.error);
          setApiResponse(first.apiResponse || first.error);
          return;
        }
        setDestination(first.destination);
        setDemo(Boolean(first.demo));
        setDurationMs(first.durationMs);
        setPhase("success");
        void copyText(first.destination);
        return;
      }

      const data = await runOne(url.trim());
      if (!data.ok) {
        setPhase("error");
        setError(data.error);
        setApiResponse(data.apiResponse || data.error);
        return;
      }
      setDestination(data.destination);
      setDemo(Boolean(data.demo));
      setDurationMs(data.durationMs);
      setPhase("success");
      void copyText(data.destination);
    } catch (err) {
      setPhase("error");
      setError("Network error — please try again.");
      setApiResponse(err instanceof Error ? err.message : "Network request failed");
    }
  }

  function extractClipboardUrl(text: string): string {
    const trimmed = text.trim();
    if (!trimmed) return "";
    try {
      const parsed = new URL(trimmed);
      if (parsed.protocol === "http:" || parsed.protocol === "https:") return trimmed;
    } catch {
      // fall through — try to find a URL inside pasted text
    }
    const match = trimmed.match(/https?:\/\/[^\s<>"'`]+/i);
    return match ? match[0].replace(/[),.;]+$/, "") : trimmed;
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
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setError("Copy failed");
    }
  }

  async function pasteFromClipboard() {
    setPasteError(null);
    try {
      if (!navigator.clipboard?.readText) {
        setPasteError("Clipboard paste isn’t available in this browser.");
        return;
      }
      const raw = await navigator.clipboard.readText();
      const next = extractClipboardUrl(raw);
      if (!next) {
        setPasteError("Clipboard is empty.");
        return;
      }
      setUrl(next);
      setPasted(true);
      window.setTimeout(() => setPasted(false), 1400);
    } catch {
      setPasteError("Allow clipboard access to paste.");
    }
  }

  async function shareResult(value: string) {
    if (canShare) {
      try {
        await navigator.share({
          title: "Void Syndicate",
          text: value,
          url: value,
        });
        return;
      } catch {
        // user cancelled or share failed — fall through to copy
      }
    }
    await copyText(value);
  }

  function resetResult() {
    setPhase("idle");
    setDestination(null);
    setError(null);
    setApiResponse(null);
    setDemo(false);
    setCopied(false);
    setPasteError(null);
  }

  return (
    <div className="site">
      <header className="top">
        <button type="button" className="logo" onClick={goHome}>
          <span className="logo-mark">
            <LightningIcon />
          </span>
          <span>Void Syndicate</span>
        </button>

        <nav className="desktop-nav" aria-label="Primary">
          <button type="button" className={view === "home" ? "active" : ""} onClick={goHome}>
            Home
          </button>
          <a href="#why" onClick={() => setView("home")}>
            Supported
          </a>
          <button type="button" className={view === "pricing" ? "active" : ""} onClick={goPricing}>
            Pricing
          </button>
          <button type="button" className={view === "bot" ? "active" : ""} onClick={goBot}>
            Bot
          </button>
          <button type="button" className={view === "docs" ? "active" : ""} onClick={goDocs}>
            Docs
          </button>
          <button type="button" className={view === "extension" ? "active" : ""} onClick={goExtension}>
            Extension
          </button>
        </nav>

        <div className="top-actions">
          <button type="button" className="icon-btn" aria-label="Notifications">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
              <path d="M6 9a6 6 0 0 1 12 0c0 7 3 7 3 7H3s3 0 3-7" />
              <path d="M10 19a2 2 0 0 0 4 0" />
            </svg>
            <span className="dot" />
          </button>
          <button
            type="button"
            className="icon-btn"
            aria-label="API key"
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
          <a className="icon-btn" href="#faq" aria-label="Status" onClick={() => setView("home")}>
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
              <path d="M3 12h4l2-5 4 10 2-5h6" />
            </svg>
          </a>
          <button type="button" className="icon-btn" aria-label="Contact" onClick={goContact}>
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
              <rect x="3" y="5" width="18" height="14" rx="2" />
              <path d="m3 7 9 7 9-7" />
            </svg>
          </button>
          <a
            className="icon-btn discord-icon"
            href={DISCORD_INVITE}
            target="_blank"
            rel="noreferrer"
            aria-label="Discord"
          >
            <DiscordIcon />
          </a>
          <a className="login-btn desktop-only" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
            Login
          </a>
          <button
            type="button"
            className="icon-btn"
            aria-label={menuOpen ? "Close menu" : "Open menu"}
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
        <div className="site-menu" role="dialog" aria-label="Menu">
          <nav className="site-menu-links">
            <button type="button" className={view === "home" ? "active" : ""} onClick={goHome}>
              Home
            </button>
            <a
              href="#why"
              onClick={(e) => {
                e.preventDefault();
                goHome();
                window.setTimeout(() => document.getElementById("why")?.scrollIntoView({ behavior: "smooth" }), 50);
              }}
            >
              Supported
            </a>
            <button type="button" className={view === "pricing" ? "active" : ""} onClick={goPricing}>
              Pricing
            </button>
            <button type="button" className={view === "bot" ? "active" : ""} onClick={goBot}>
              Bot
            </button>
            <button type="button" className={view === "docs" ? "active" : ""} onClick={goDocs}>
              Docs
            </button>
            <button type="button" className={view === "extension" ? "active" : ""} onClick={goExtension}>
              Extension
            </button>
          </nav>

          <div className="site-menu-grid">
            <button
              type="button"
              onClick={() => {
                setMenuOpen(false);
                setDraftKey(apiKey);
                setShowKeyModal(true);
              }}
            >
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.8">
                <rect x="5" y="11" width="14" height="10" rx="2" />
                <path d="M8 11V8a4 4 0 0 1 8 0v3" />
              </svg>
              API key
            </button>
            <a href="#faq" onClick={() => { setMenuOpen(false); setView("home"); }}>
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.8">
                <path d="M3 12h4l2-5 4 10 2-5h6" />
              </svg>
              Status
            </a>
            <button type="button" onClick={goContact}>
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.8">
                <rect x="3" y="5" width="18" height="14" rx="2" />
                <path d="m3 7 9 7 9-7" />
              </svg>
              Contact
            </button>
            <a href={DISCORD_INVITE} target="_blank" rel="noreferrer" onClick={() => setMenuOpen(false)}>
              <DiscordIcon size={16} />
              Discord
            </a>
          </div>

          <a className="login-btn menu-login" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
            <DiscordIcon size={16} />
            Login
          </a>
        </div>
      ) : null}

      <main id="top" className="main">
        {view === "home" ? (
          <>
            <section className="hero">
              <p className="pill">
                <span className="pill-dot" />
                Fast, free link bypassing
              </p>
              <h1>
                Skip the wait.
                <span>Get to the link.</span>
              </h1>
              <p className="lede">
                Paste any supported link and let Void Syndicate take care of the
                redirects, timers, and clutter.{" "}
                <a href="#why">Browse Reference</a>
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
                  <div className={`copy-pulse${copied ? " on" : ""}`} aria-live="polite">
                    {copied ? "Copied to clipboard" : "Ready"}
                  </div>
                  <div className="result-box">{destination}</div>
                  <div className={`result-actions${canShare ? " with-share" : ""}`}>
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
                      className={`secondary-btn${copied ? " copied-flash" : ""}`}
                      onClick={() => copyText(destination)}
                    >
                      {copied ? "Copied!" : "Copy"}
                    </button>
                    {canShare ? (
                      <button
                        type="button"
                        className="secondary-btn share-btn"
                        onClick={() => shareResult(destination)}
                      >
                        Share
                      </button>
                    ) : null}
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
                        className="text-link muted-link"
                        onClick={() => {
                          setDraftKey(apiKey);
                          setShowKeyModal(true);
                        }}
                      >
                        {hasKey ? "API key saved" : "Add API key"}
                      </button>
                    </div>
                  </div>

                  <form onSubmit={onSubmit} className="bypass-form">
                    {mode === "single" ? (
                      <div className="submit-row">
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
                            onChange={(e) => {
                              setUrl(e.target.value);
                              setPasteError(null);
                            }}
                            autoComplete="off"
                            spellCheck={false}
                          />
                          <button
                            type="button"
                            className={`field-paste${pasted ? " pasted" : ""}`}
                            onClick={pasteFromClipboard}
                            aria-label="Paste link from clipboard"
                          >
                            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
                              <rect x="8" y="8" width="12" height="12" rx="2" />
                              <path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" />
                            </svg>
                            <span>{pasted ? "Pasted" : "Paste"}</span>
                          </button>
                        </label>
                        <button type="submit" className="primary-btn">
                          Bypass <span aria-hidden="true">→</span>
                        </button>
                      </div>
                    ) : (
                      <>
                        <textarea
                          className="bulk-field"
                          required
                          rows={5}
                          placeholder={placeholders}
                          value={bulkText}
                          onChange={(e) => setBulkText(e.target.value)}
                          spellCheck={false}
                        />
                        <button type="submit" className="primary-btn wide">
                          Bypass <span aria-hidden="true">→</span>
                        </button>
                      </>
                    )}
                    {pasteError ? (
                      <p className="paste-hint" role="status">
                        {pasteError}
                      </p>
                    ) : null}
                    {error ? (
                      <div className="error-box" role="alert">
                        <div className="error-box-head">
                          <span className="error-box-icon" aria-hidden="true">
                            !
                          </span>
                          <strong>Error</strong>
                        </div>
                        <p className="error-box-msg">
                          {apiResponse || error}
                        </p>
                        {apiResponse && apiResponse !== error ? (
                          <p className="error-box-hint">{error}</p>
                        ) : null}
                      </div>
                    ) : null}
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
                <strong>46,411,364</strong>
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
                    the input. Bulk mode unlocks with an API key.
                  </p>
                </article>
                <article>
                  <div className="step-meta">
                    <span className="step-num">02</span>
                    <span>step</span>
                  </div>
                  <h3>We handle the wait</h3>
                  <p>
                    No captcha on Void Syndicate. Paste your link and we resolve it
                    through our API — fast, free, no surveys.
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
              <h2>Why choose Void Syndicate?</h2>
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
                  Grab an API key on Discord for bulk mode and your own apps.
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
                <button type="button" className="outline-btn" onClick={goContact}>
                  Contact us ↗
                </button>
              </div>
            </section>
          </>
        ) : null}

        {view === "contact" ? (
          <section className="page-view contact-view">
            <article className="info-card">
              <div className="feature-icon">
                <DiscordIcon />
              </div>
              <h2>Discord</h2>
              <p className="lede-left">
                Fastest way to get help, report bugs, or request new services.
              </p>
              <ul className="checks-left">
                <li>Bug reports</li>
                <li>Bypass not working</li>
                <li>Request a new service</li>
                <li>General help & questions</li>
              </ul>
              <a className="primary-btn wide" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                Join Discord ↗
              </a>
            </article>

            <article className="info-card">
              <div className="feature-icon">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <rect x="3" y="5" width="18" height="14" rx="2" />
                  <path d="m3 7 9 7 9-7" />
                </svg>
              </div>
              <h2>Email</h2>
              <a className="accent-link" href={`mailto:${CONTACT_EMAIL}`}>
                {CONTACT_EMAIL}
              </a>
              <p className="lede-left">
                For formal inquiries, business, and anything that doesn't fit in a chat message.
              </p>
              <ul className="checks-left">
                <li>Business & partnership</li>
                <li>Press & media</li>
                <li>API customer onboarding</li>
                <li>Suggestion & feedback</li>
              </ul>
              <a className="secondary-btn wide" href={`mailto:${CONTACT_EMAIL}`}>
                Send email ↗
              </a>
              <p className="mailto-hint">
                Prefer your own email client?{" "}
                <a href={`mailto:${CONTACT_EMAIL}`}>Use mailto</a>
              </p>
            </article>

            <article className="info-card soft">
              <p className="eyebrow">Looking for something else?</p>
              <div className="chip-row">
                <span className="chip">
                  <i className="chip-dot" /> Service status
                </span>
                <button type="button" className="chip" onClick={goHome}>
                  Supported services
                </button>
                <button type="button" className="chip" onClick={goPricing}>
                  API pricing
                </button>
                <button type="button" className="chip" onClick={goDocs}>
                  API docs
                </button>
              </div>
            </article>
          </section>
        ) : null}

        {view === "bot" ? (
          <section className="page-view bot-view">
            <div className="bot-hero">
              <p className="eyebrow">Discord bot</p>
              <h1>Bypass from Discord</h1>
              <p className="lede-left">
                Add the Void Syndicate bot to your server and run{" "}
                <code>/bypass</code> without leaving Discord.
              </p>
              <a className="primary-btn" href={BOT_INVITE} target="_blank" rel="noreferrer">
                Add to Server ↗
              </a>
            </div>

            <p className="eyebrow">Features</p>
            <div className="feature-stack">
              <article className="feature">
                <h3>Slash commands</h3>
                <p>
                  Bypass links without leaving Discord. Just run a command and get
                  the result in the channel.
                </p>
              </article>
              <article className="feature">
                <h3>All supported services</h3>
                <p>
                  Works with every service listed on Supported — Linkvertise, Lootlabs,
                  Admaven, Rekonise, Workink, Platoboost, Codex, Hydrogen and more.
                </p>
              </article>
              <article className="feature">
                <h3>Fast & reliable</h3>
                <p>
                  Backed by the same infrastructure as the website and API, with 24/7
                  availability.
                </p>
              </article>
              <article className="feature">
                <h3>Free to use</h3>
                <p>
                  No subscription required for basic usage. Premium access is available
                  for high-volume servers.
                </p>
              </article>
            </div>

            <article className="info-card">
              <h2>Getting started</h2>
              <ol className="numbered-steps">
                <li>
                  <span>1</span>
                  <p>
                    Click <strong>Add to Server</strong> above and sign in to Discord.
                  </p>
                </li>
                <li>
                  <span>2</span>
                  <p>
                    Pick the server you want to add the bot to. You need the{" "}
                    <strong>Manage Server</strong> permission.
                  </p>
                </li>
                <li>
                  <span>3</span>
                  <p>
                    Run <code>/bypass</code> in any channel the bot can access and paste
                    your link.
                  </p>
                </li>
              </ol>
            </article>

            <article className="info-card glow">
              <h2>Need help?</h2>
              <p className="lede-left">
                Setup help, bug reports, or service requests — we're on Discord.
              </p>
              <a className="outline-btn" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                Join Support ↗
              </a>
            </article>
          </section>
        ) : null}

        {view === "pricing" ? (
          <section className="page-view pricing-view">
            <div className="pricing-hero">
              <p className="eyebrow">API access</p>
              <h1>Simple pricing</h1>
              <p className="lede-left">
                Flexible credits or unlimited monthly access. Keys are issued on Discord
                after payment — no self-checkout.
              </p>
            </div>

            <div className="pricing-grid">
              {PLANS.map((plan) => (
                <article
                  key={plan.id}
                  className={`pricing-card${plan.recommended ? " recommended" : ""}`}
                >
                  {plan.recommended ? <span className="plan-badge">Recommended</span> : null}
                  <h2>{plan.name}</h2>
                  <p className="plan-price">
                    <strong>{plan.price}</strong>
                    <span>{plan.unit}</span>
                  </p>
                  <p className="plan-blurb">{plan.blurb}</p>
                  <ul className="plan-features">
                    {plan.features.map((f) => (
                      <li key={f}>{f}</li>
                    ))}
                  </ul>
                  <a className="primary-btn wide" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                    {plan.cta} ↗
                  </a>
                  <p className="plan-best">{plan.best}</p>
                </article>
              ))}
            </div>

            <article className="info-card soft pay-methods">
              <p className="eyebrow">Payment methods</p>
              <h2>How to pay</h2>
              <div className="pay-grid">
                <div>
                  <h3>Crypto</h3>
                  <p>LTC, USDT, ETH</p>
                </div>
                <div>
                  <h3>Binance</h3>
                  <p>Pay direct</p>
                </div>
                <div>
                  <h3>PayPal</h3>
                  <p>Invoice</p>
                </div>
              </div>
              <a className="outline-btn" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                Open Discord to buy ↗
              </a>
            </article>

            <article className="info-card">
              <p className="eyebrow">Developers</p>
              <h2>Ready to integrate?</h2>
              <p className="lede-left">
                Authenticate with <code>x-api-key</code> and call{" "}
                <code>/api/v1/bypass</code>. Full reference on Docs.
              </p>
              <button type="button" className="secondary-btn" onClick={goDocs}>
                Open API docs
              </button>
            </article>
          </section>
        ) : null}

        {view === "docs" ? (
          <section className="page-view docs-view">
            <div className="pricing-hero">
              <p className="eyebrow">API documentation</p>
              <h1>Void Syndicate API</h1>
              <p className="lede-left">
                Resolve supported shortlinks, key systems and ad-locked URLs. Authenticate
                with an <code>x-api-key</code> header and make simple GET requests.
              </p>
              <a className="primary-btn" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                Get an API key on Discord ↗
              </a>
            </div>

            <article className="info-card docs-block">
              <h2>Authentication</h2>
              <p>
                Every request must include your API key in the <code>x-api-key</code>{" "}
                header. Keys are issued per customer and requested on Discord (Pricing →
                Buy).
              </p>
              <pre className="code-block">{`x-api-key: YOUR_API_KEY`}</pre>
            </article>

            <article className="info-card docs-block">
              <h2>Quickstart</h2>
              <p>
                Send a GET request to <code>/api/v1/bypass</code> with the{" "}
                <code>url</code> query parameter and your API key.
              </p>
              <pre className="code-block">{`curl -X GET "https://YOUR_DOMAIN/api/v1/bypass?url=https%3A%2F%2Flinkvertise.com%2F..." \\
  -H "x-api-key: YOUR_API_KEY"`}</pre>
              <pre className="code-block">{`{
  "status": "success",
  "result": "https://example.com/destination",
  "time": "1.23"
}`}</pre>
            </article>

            <article className="info-card docs-block">
              <h2>Endpoints</h2>
              <div className="endpoint">
                <code className="method">GET</code>
                <code>/api/v1/bypass?url=</code>
                <p>Bypass a URL. Returns cached result when available. Auth required.</p>
              </div>
              <div className="endpoint">
                <code className="method">GET</code>
                <code>/api/v1/refresh?url=</code>
                <p>Force a fresh bypass (skip cache). Auth required.</p>
              </div>
              <div className="endpoint">
                <code className="method">GET</code>
                <code>/api/v1/supported</code>
                <p>List supported services. No auth required.</p>
              </div>
            </article>

            <article className="info-card docs-block">
              <h2>Errors</h2>
              <ul className="error-list">
                <li>
                  <strong>400</strong> Missing or invalid <code>url</code>, or unsupported
                  service
                </li>
                <li>
                  <strong>401</strong> Missing or invalid <code>x-api-key</code>
                </li>
                <li>
                  <strong>429</strong> Rate limit exceeded (rare — Monthly is unlimited)
                </li>
                <li>
                  <strong>500</strong> Upstream failure — safe to retry once
                </li>
              </ul>
            </article>

            <article className="info-card soft">
              <p className="eyebrow">Need a key?</p>
              <h2>Buy access on Discord</h2>
              <p className="lede-left">
                Same plans as Pricing — pay-as-you-go or monthly unlimited. We issue your
                key after payment.
              </p>
              <div className="chip-row">
                <button type="button" className="chip" onClick={goPricing}>
                  View pricing
                </button>
                <a className="chip" href={DISCORD_INVITE} target="_blank" rel="noreferrer">
                  Join Discord
                </a>
              </div>
            </article>
          </section>
        ) : null}

        {view === "extension" ? (
          <section className="page-view extension-view">
            <div className="pricing-hero">
              <p className="eyebrow">Browser extension</p>
              <h1>Bypass without leaving the page</h1>
              <p className="lede-left">
                Right-click any link, use the toolbar popup, or tap the floating Void
                button on Linkvertise / Work.ink / Lootlabs — result opens instantly.
              </p>
              <a className="primary-btn" href="/void-syndicate-extension.zip" download>
                Download extension ZIP ↗
              </a>
            </div>

            <article className="info-card glow">
              <p className="eyebrow">What you get</p>
              <ul className="checks-left">
                <li>Toolbar popup with Paste + Bypass</li>
                <li>Right-click → “Bypass with Void Syndicate”</li>
                <li>Floating button on supported adlink sites</li>
                <li>Uses your Void API key (`vs_…`) securely in the browser</li>
              </ul>
            </article>

            <article className="info-card">
              <p className="eyebrow">Install — Chrome / Edge / Brave</p>
              <h2>Load unpacked (2 minutes)</h2>
              <ol className="numbered-steps">
                <li>
                  <span>1</span>
                  <p>
                    Download the ZIP and <strong>unzip</strong> it (you need the folder,
                    not the ZIP itself).
                  </p>
                </li>
                <li>
                  <span>2</span>
                  <p>
                    Open <code>chrome://extensions</code> (or <code>edge://extensions</code>)
                    and enable <strong>Developer mode</strong>.
                  </p>
                </li>
                <li>
                  <span>3</span>
                  <p>
                    Click <strong>Load unpacked</strong> and select the unzipped{" "}
                    <code>extension</code> folder.
                  </p>
                </li>
                <li>
                  <span>4</span>
                  <p>
                    Open the extension popup → paste your <code>vs_…</code> API key →
                    Save. Get a key on Pricing / Discord if you don’t have one.
                  </p>
                </li>
              </ol>
              <div className="chip-row">
                <a className="chip" href="/void-syndicate-extension.zip" download>
                  Download ZIP
                </a>
                <button type="button" className="chip" onClick={goPricing}>
                  Get API key
                </button>
              </div>
            </article>

            <article className="info-card">
              <p className="eyebrow">Firefox</p>
              <h2>Temporary add-on</h2>
              <ol className="numbered-steps">
                <li>
                  <span>1</span>
                  <p>
                    Open <code>about:debugging#/runtime/this-firefox</code>
                  </p>
                </li>
                <li>
                  <span>2</span>
                  <p>
                    <strong>Load Temporary Add-on…</strong> → pick{" "}
                    <code>manifest.json</code> from the unzipped folder.
                  </p>
                </li>
              </ol>
              <p className="lede-left">
                Chrome Web Store publish comes later (one-time $5 developer fee). Until
                then, Developer mode install works for you and your Discord members.
              </p>
            </article>
          </section>
        ) : null}
      </main>

      <footer className="footer">
        <div className="footer-brand">
          <button type="button" className="logo" onClick={goHome}>
            <span className="logo-mark">
              <LightningIcon />
            </span>
            <span>Void Syndicate</span>
          </button>
          <p>
            Free bypasser for Linkvertise, Work.ink, Lootlabs, Admaven and key
            systems. Fast, free, no wait.
          </p>
          <div className="footer-social">
            <a href={DISCORD_INVITE} target="_blank" rel="noreferrer" aria-label="Discord">
              <DiscordIcon />
            </a>
            <a href={`mailto:${CONTACT_EMAIL}`} aria-label="Email">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8">
                <rect x="3" y="5" width="18" height="14" rx="2" />
                <path d="m3 7 9 7 9-7" />
              </svg>
            </a>
          </div>
        </div>
        <div className="footer-cols">
          <div>
            <h4>Product</h4>
            <button type="button" className="footer-link" onClick={goHome}>
              Home
            </button>
            <button type="button" className="footer-link" onClick={goHome}>
              Supported
            </button>
            <button type="button" className="footer-link" onClick={goBot}>
              Bot
            </button>
            <button type="button" className="footer-link" onClick={goPricing}>
              Pricing
            </button>
          </div>
          <div>
            <h4>Resources</h4>
            <button type="button" className="footer-link" onClick={goDocs}>
              Docs
            </button>
            <button type="button" className="footer-link" onClick={goExtension}>
              Extension
            </button>
            <button
              type="button"
              className="footer-link"
              onClick={() => {
                goHome();
                window.setTimeout(() => document.getElementById("faq")?.scrollIntoView({ behavior: "smooth" }), 50);
              }}
            >
              FAQ
            </button>
            <a href={DISCORD_INVITE} target="_blank" rel="noreferrer">
              Discord
            </a>
          </div>
          <div>
            <h4>Legal</h4>
            <button type="button" className="footer-link" onClick={goContact}>
              Contact
            </button>
            <a href={`mailto:${CONTACT_EMAIL}`}>Email</a>
          </div>
        </div>
        <div className="footer-bottom">
          <span className="status">
            <i /> Operational
          </span>
          <span>Void Syndicate © 2026</span>
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
              Optional — unlocks <strong>Bulk</strong> on the site and our public API.
              Stored locally in your browser and sent as <code>x-api-key</code>.
              Get a key on Discord (Pricing).
            </p>
            <input
              type="password"
              value={draftKey}
              onChange={(e) => setDraftKey(e.target.value)}
              placeholder="your-api-key"
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
