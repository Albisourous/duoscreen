# duoscreen

Get the two-browser experience on your current iPhone, like iPhone Duo — an installable PWA with two web panes, a draggable liquid-glass divider, and per-pane address bars.

## Native app (recommended)

`ios/` contains the real iPhone app — two native `WKWebView`s, so **every site works**, with Apple's Liquid Glass UI. Requires Xcode:

```bash
cd ios && xcodegen && open DuoScreen.xcodeproj
```

In Xcode: select the DuoScreen target → Signing & Capabilities → choose your team (a free Apple ID works) → plug in your iPhone → Run.

## Web version

```bash
npm install
npm run dev -- --host
```

On iPhone (same Wi-Fi): `http://<mac-ip>:8003` → Share → Add to Home Screen. Some sites (Google, X, DuckDuckGo…) refuse iframe embedding via `X-Frame-Options`; use the ↗ button to open them in Safari instead.

See `AGENTS.md` for stack and agent-tooling notes.
