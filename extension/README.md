# Void Syndicate Browser Extension

Chrome / Edge / Brave / Firefox (Manifest V3).

## What it does

1. **Toolbar popup** — paste a link + your `vs_…` API key → Bypass  
2. **Right-click menu** — “Bypass with Void Syndicate” on links / page / selection  
3. **Floating button** on supported adlink sites → one-tap bypass + redirect  

Calls: `GET https://void-syndicate-954.netlify.app/api/v1/bypass?url=…`  
Header: `x-api-key: <your Void key>`

## Install (developer mode)

### Chrome / Edge / Brave
1. Open `chrome://extensions` (or `edge://extensions`)
2. Enable **Developer mode**
3. **Load unpacked** → select this `extension/` folder  
   Or install the ZIP from the website (unpack first, then load the folder)

### Firefox
1. Open `about:debugging#/runtime/this-firefox`
2. **Load Temporary Add-on…** → pick `manifest.json`

## Publish later (Chrome Web Store)
1. Zip the `extension/` folder
2. Pay $5 Chrome Web Store developer registration
3. Upload ZIP at https://chrome.google.com/webstore/devconsole
