# VAIs

Multi-model AI chat app (Agent X, Battle, Side-by-Side, Direct) — rebuilt from the live deployment at [vais-dvvk.onrender.com](https://vais-dvvk.onrender.com/) after the original GitHub repo was lost.

## Stack

- **Frontend:** original production static assets (HTML/CSS/JS)
- **Backend:** Node.js + Express (this rebuild)
- **Database:** local SQLite (`data/vais.db`); original used Turso
- **Models:** Groq (+ optional OpenRouter), images via Pollinations

## Quick start

```bash
cp .env.example .env
# set GROQ_API_KEY (and/or OPENROUTER_API_KEY)
npm install
npm run dev
```

Open http://127.0.0.1:3000

With `AUTH_DEV=1` (default in `.env.example`):

- verification codes are printed in the server log
- code `123456` always works

## Deploy on Render

1. Push this repo to GitHub
2. New Web Service → connect the repo
3. Build: `npm install` · Start: `npm start`
4. Set env: `SESSION_SECRET`, `GROQ_API_KEY`, optional `OPENROUTER_API_KEY`, `ADMIN_EMAIL`, `AUTH_DEV=0`

Or use `render.yaml`.

## What was recovered vs rebuilt

| Part | Source |
| --- | --- |
| UI (login, app, styles, i18n, PWA) | Mirrored from live site |
| Auth, chat CRUD, NDJSON streaming | Reimplemented to match frontend API |
| Teams, push, sites publish, admin panel | Stubbed / not fully ported |
| Original server source | Not found on GitHub |

## API compatibility

The frontend expects the same routes as production (`/api/auth/*`, `/api/chat/*`, `/api/status`). Streaming answers are NDJSON lines with `{ t }`, `{ r }`, `{ done }`, etc.
