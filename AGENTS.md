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
- `ContentView.swift` — split layout + the seam. Upright stacks the two panes top/bottom; landscape puts them side-by-side — the Duo fold. The seam is 3pt; a pane never shrinks below ~120pt (`lo` floor in `divider`). Keep the code minimal — delete dead code as you go. Divider: 3pt dark seam, `DragGesture(minimumDistance: 0)` with ±20pt invisible grab area, double-tap locks/unlocks (glass lock badge, drags ignored). During a drag the live `WKWebView`s keep their pre-drag size and a `scaleEffect` squish tracks the finger (same presentation-transform trick WebKit uses for live resize) — resizing a webview reflows the page (the jank); panes commit once on release to `@AppStorage("duo.split.v2")`. Never animate `split` on drop — an animated frame reflows for the whole spring.
- `BrowserView.swift` — one pane: `WebStore` (owns the `WKWebView`, `WKNavigationDelegate`, persisted URL under `duo.url.a/b`), `WebView` (UIViewRepresentable + scroll delegate for Safari-style chrome auto-hide), `BrowserView` (bottom address bar).

## Chrome conventions (Duo renders)

- Per-pane Safari-style **bottom bar**: back, centered domain pill (tap to expand into the address field), reload — one glass capsule. Auto-hides on scroll down, reveals on scroll up / at top / while editing.
- Layout ignores safe area (panes flush to screen edges); all chrome pads with `geo.safeAreaInsets` passed in as `insets`.
- Liquid Glass = real `.glassEffect()` (iOS 26). No CSS approximations, no custom blur code.
- `allowsInlineMediaPlayback = true` — videos play in-page, never auto-fullscreen.

## Navigation rules

- Allow `http`/`https` only; cancel everything else (`youtube://`, `itms:`, `tel:`…).
- `.linkActivated` navigations are cancelled and reloaded as plain loads — that's what keeps universal links (YouTube, Google, Maps) inside the pane instead of handing off to native apps.

## Gotchas

- `didFinish` syncs `urlText` from `webView.url` — that's what keeps the domain pill fresh after in-page link taps (webview url isn't observable directly).
- `scrollView.contentInsetAdjustmentBehavior = .never` — chrome overlays handle insets; don't let WebKit double-apply.
- PWA/web prototype was deleted — it's in git history (pre-cleanup commits) if ever needed.

## Agent tooling

- **Ponytail** ([DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)) — Devin skills in `.devin/skills/` (`/ponytail`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`). Lazy senior dev rules apply: climb the ladder (need it? exists? stdlib? native? dep? one line?), deletion over addition, mark deliberate shortcuts with `ponytail:` comments.
- **manus.im** — design/prototyping critique only; not a dependency, nothing calls it.

## Git

Commits are authored as `Albisourous <43053302+Albisourous@users.noreply.github.com>`. No agent/AI co-author trailers — plain `git commit -m` only. Push to `origin/main`.
