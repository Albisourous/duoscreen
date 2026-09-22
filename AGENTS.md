# DuoScreen

Two browser panes on one iPhone — the iPhone Duo split-browsing experience. One screen, two sites, a draggable divider. Native SwiftUI + `WKWebView`, no web/PWA variant (iframes can't replicate it — `X-Frame-Options` blocks half the web; top-level web-view loads ignore it). Keep the experience and the code simple.

## Build & run

```bash
cd ios && xcodegen        # regenerates DuoScreen.xcodeproj from project.yml — never edit the .xcodeproj
open DuoScreen.xcodeproj  # Xcode required
```

Device install via CLI (works once a Personal Team is set in `project.yml`):

```bash
xcodebuild -project ios/DuoScreen.xcodeproj -scheme DuoScreen \
  -destination 'id=<device-id>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-id> \
  ~/Library/Developer/Xcode/DerivedData/DuoScreen-*/Build/Products/Debug-iphoneos/DuoScreen.app
```

First launch on device: Settings → General → VPN & Device Management → trust the developer profile. Free-account signing expires after 7 days — rebuild to refresh.

## Architecture

Three files, keep it that way:

- `DuoScreenApp.swift` — `@main`, just `WindowGroup { ContentView() }`.
- `ContentView.swift` — split layout + the seam. Upright stacks the two panes top/bottom; landscape puts them side-by-side — the Duo fold. The seam is 3pt; a pane never shrinks below ~120pt (`lo` floor in `divider`). Keep the code minimal — delete dead code as you go. Divider: 3pt dark seam, `DragGesture(minimumDistance: 0)` with ±20pt invisible grab area, double-tap locks/unlocks (glass lock badge, drags ignored). During a drag, panes render as `takeSnapshot` images — reflowing two live `WKWebView`s per frame is the jank; commit to `@AppStorage("duo.split")` once on release.
- `BrowserView.swift` — one pane: `WebStore` (owns the `WKWebView`, `WKNavigationDelegate`, persisted URL under `duo.url.a/b`), `WebView` (UIViewRepresentable + scroll delegate for Safari-style chrome auto-hide), `BrowserView` (edge rail + domain pill).

## Chrome conventions (Duo renders)

- Per-pane **edge rail** on the outer edge: status column (camera dot, time, wifi, real battery level) + glass button clusters (back/reload, home/Safari). Rail edge: leading for the left pane in landscape, trailing otherwise.
- **Domain pill** at the bottom center shows the host; tap to expand into the address field. System status bar is hidden (`statusBarHidden`) so per-pane status is the only one.
- Layout ignores safe area (panes flush to screen edges); all chrome pads with `geo.safeAreaInsets` passed in as `insets`.
- Liquid Glass = real `.glassEffect()` (iOS 26). No CSS approximations, no custom blur code.
- `allowsInlineMediaPlayback = true` — videos play in-page, never auto-fullscreen.

## Navigation rules

- Allow `http`/`https` only; cancel everything else (`youtube://`, `itms:`, `tel:`…).
- `.linkActivated` navigations are cancelled and reloaded as plain loads — that's what keeps universal links (YouTube, Google, Maps) inside the pane instead of handing off to native apps.
- Open-in-Safari is explicit user action only (rail button).

## Gotchas

- `didFinish` syncs `urlText` from `webView.url` — that's what keeps the domain pill fresh after in-page link taps (webview url isn't observable directly).
- `scrollView.contentInsetAdjustmentBehavior = .never` — chrome overlays handle insets; don't let WebKit double-apply.
- Snapshot race: only apply `takeSnapshot` results while `dragSplit != nil`, or a stale image lands on a live pane and eats touches.
- PWA/web prototype was deleted — it's in git history (pre-cleanup commits) if ever needed.

## Agent tooling

- **Ponytail** ([DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)) — Devin skills in `.devin/skills/` (`/ponytail`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`). Lazy senior dev rules apply: climb the ladder (need it? exists? stdlib? native? dep? one line?), deletion over addition, mark deliberate shortcuts with `ponytail:` comments.
- **manus.im** — design/prototyping critique only; not a dependency, nothing calls it.

## Git

Commits are authored as `Albisourous <43053302+Albisourous@users.noreply.github.com>`. No agent/AI co-author trailers — plain `git commit -m` only. Push to `origin/main`.
