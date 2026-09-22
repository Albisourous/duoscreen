# duoscreen

Get the two-browser experience on your current iPhone, like iPhone Duo — two native web panes, a draggable divider with double-tap lock, and per-pane edge-rail chrome in Apple's Liquid Glass.

## Build & install

Requires Xcode. `ios/` is the whole app — three Swift files.

```bash
cd ios && xcodegen && open DuoScreen.xcodeproj
```

In Xcode: select the DuoScreen target → Signing & Capabilities → choose your team (a free Apple ID works, 7-day cert) → plug in your iPhone → Run. On first launch, trust the developer profile under Settings → General → VPN & Device Management.

See `AGENTS.md` for architecture and conventions.
