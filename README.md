# OPENLINK

Link-Bypass-Webseite: URL eingeben → Zielseite über deine Bypass-API freischalten.

## Lokal starten

```bash
npm install
npm run dev
```

Ohne `BYPASS_API_URL` / `BYPASS_API_KEY` läuft ein Demo-Modus.

## API verbinden

Kopiere `.env.example` nach `.env` und setze:

| Variable | Bedeutung |
|---|---|
| `BYPASS_API_URL` | Endpoint deiner Bypass-API |
| `BYPASS_API_KEY` | Dein API-Key |
| `BYPASS_API_AUTH` | `query` (Standard), `header`, `bearer` oder `authorization` |
| `BYPASS_API_METHOD` | `GET` (Standard) oder `POST` |
| `BYPASS_API_URL_PARAM` | Query/Body-Feld für die URL (Standard `url`) |
| `BYPASS_API_KEY_PARAM` | Query/Body-Feld für den Key (Standard `api_key`) |

Der Key bleibt serverseitig in der Netlify Function `/api/bypass` — nie im Browser.

## Deploy (Netlify)

```bash
npm run build
npx netlify deploy
```

Setze dieselben Env-Vars in den Netlify Site Settings.
