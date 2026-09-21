# DuoScreen

Two browser panes on one iPhone — the iPhone Duo split-browsing experience as an installable PWA. One screen, two sites, a draggable glass divider.

## Commands

```bash
npm run dev      # Vite dev server
npm run build    # tsc -b && vite build (typecheck + bundle)
npm run lint     # oxlint
```

## Stack

- **Vite + React 19 + TypeScript** — no SSR, static PWA.
- **Tailwind CSS v4** — via `@tailwindcss/vite`, tokens in `src/index.css` (`@theme inline` + `.dark`).
- **shadcn/ui** — primitives in `src/components/ui/` (`button`, `card`). Registry config in `components.json`.
- **KokonutUI** (`kokonutui.com`) — installed via the `@kokonutui` shadcn registry: `npx shadcn@latest add @kokonutui/<name>`. Currently vendored: `src/components/kokonutui/liquid-glass-card.tsx` (exports `LiquidGlassCard`, `LiquidButton`; the upstream demo/`next/image` code was removed for Vite).
- **Motion** (`motion.dev`) — `import { motion, animate } from "motion/react"`. Used for toolbar spring-in, chip stagger, divider handle press, split reset spring.
- **lucide-react** — icons.
- **radix-ui** — shadcn `Button` Slot dependency.

## Architecture

Two files do the work — keep it that way:

- `src/App.tsx` — split container (`h-dvh`, `flex-col` portrait / `flex-row` landscape), draggable divider with glass handle (swap / reset / rotate), `localStorage` persistence under `duoscreen.v1`.
- `src/Pane.tsx` — one browser pane: `<iframe>` + floating glass omnibox (back / reload / address / home / open-in-Safari) + start screen with quick-launch chips.

## iPhone notes

- `viewport-fit=cover` + `user-scalable=no` in `index.html`; safe-area insets applied inline on the toolbars (`max(env(safe-area-inset-*), 10px)`).
- PWA: `public/manifest.webmanifest` + generated icons; `apple-mobile-web-app-capable` for fullscreen Add-to-Home-Screen.
- While dragging the divider, `.dragging iframe { pointer-events: none }` — without it the iframes swallow the gesture.
- **Iframe limits:** sites sending `X-Frame-Options`/`frame-ancestors` (Google, X, DDG, MDN…) refuse to render — the ↗ button opens them in Safari. Verified embeddable: Wikipedia, Hacker News, Bing (also the search fallback), wttr.in, OpenStreetMap `export/embed.html`, example.com.

## Liquid glass conventions

- Reusable `.glass` / `.glass-strong` utilities in `src/index.css`: translucent gradient + `backdrop-filter: blur + saturate` + specular top highlight + border. Use them for any new overlay surface.
- Prefer KokonutUI `LiquidGlassCard`/`LiquidButton` for content surfaces; `.glass` for chrome (toolbars, handles).
- Dark-first: `<html class="dark">`; glass reads as white-on-dark translucency. Keep backgrounds dark enough for refraction to show.

## Agent tooling

- **Ponytail** ([DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)) — installed as Devin skills in `.devin/skills/` (`/ponytail`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`). Its ruleset applies here: lazy senior dev — climb the ladder (does it need to exist? already in codebase? stdlib? native platform? installed dep? one line?) and stop at the first rung that holds. Never lazy about validation at trust boundaries, error handling, security, accessibility. Mark deliberate shortcuts with a `ponytail:` comment.
- **motion.dev** — use `motion/react` primitives for animation; don't hand-roll springs or add a second animation library.
- **kokonut.ui** — pull components via `npx shadcn@latest add @kokonutui/<name>`; strip Next.js-only code (`next/image`, `"use client"` is harmless) when vendoring. Known quirk: the shadcn CLI may create a literal `@/` directory if run before path aliases exist — move its contents into `src/` and delete it.
- **manus.im** — general-purpose AI agent; use it for prototyping flows/copy and second-pass design critique of the glass UI. Not a runtime dependency — nothing in this repo calls it.
- Keep the experience and the code simple: two panes, one divider, no routing, no state library, no backend.

## Gotchas

- `package.json` name is still `duo-scaffold` template noise — fine, private app.
- `iframe.contentWindow.history.back()` works cross-origin (navigation is allowed); `location.reload()` is not — reload via `iframe.src = iframe.src`.
