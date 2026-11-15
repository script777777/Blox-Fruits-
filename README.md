# Void Syndicate

Link-Bypass-UI im Stil von [izen.lol](https://izen.lol/) (Zen Bypass), angebunden an die **Zen API**.

## API

Dokumentation: https://api.izen.lol/docs

```http
GET https://api.izen.lol/v1/bypass?url=<encoded>
x-api-key: <dein_key>
```

## Lokal

```bash
npm install
npm run dev
```

1. Im UI **Add API key** → Key speichern, **oder**
2. `.env` mit `BYPASS_API_KEY=...`

Ohne Key: Demo-Modus.

## Deploy

Netlify: Build `npm run build`, Publish `dist`. Env-Vars wie in `.env.example`.
