import { motion } from "motion/react";
import { ChevronLeft, ExternalLink, Home, RotateCw } from "lucide-react";
import { useRef, useState } from "react";
import {
  LiquidButton,
  LiquidGlassCard,
} from "@/components/kokonutui/liquid-glass-card";

const QUICK_SITES = [
  { name: "Wikipedia", url: "https://en.m.wikipedia.org" },
  { name: "Hacker News", url: "https://news.ycombinator.com" },
  { name: "Bing", url: "https://www.bing.com" },
  { name: "Weather", url: "https://wttr.in" },
  {
    name: "Maps",
    url: "https://www.openstreetmap.org/export/embed.html?bbox=-0.13,51.49,-0.09,51.52&layer=mapnik",
  },
  { name: "Example", url: "https://example.com" },
];

/** Bare domains get https://; anything else becomes a Bing search (Bing allows framing). */
function normalize(input: string): string {
  const v = input.trim();
  if (/^https?:\/\//i.test(v)) return v;
  if (!v.includes(" ") && (v.includes(".") || v.startsWith("localhost")))
    return `https://${v}`;
  return `https://www.bing.com/search?q=${encodeURIComponent(v)}`;
}

/** Confirm a host resolves before loading it — else the iframe shows a dead error page. */
async function resolves(url: string): Promise<boolean> {
  try {
    await fetch(url, { method: "HEAD", mode: "no-cors", signal: AbortSignal.timeout?.(4000) });
    return true;
  } catch {
    return false;
  }
}

interface PaneProps {
  url: string;
  onNavigate: (url: string) => void;
  toolbarAt: "top" | "bottom";
}

export function Pane({ url, onNavigate, toolbarAt }: PaneProps) {
  const frameRef = useRef<HTMLIFrameElement>(null);
  const [input, setInput] = useState(url);
  const [prevUrl, setPrevUrl] = useState(url);
  if (prevUrl !== url) {
    setPrevUrl(url);
    setInput(url);
  }

  // Cross-origin frames can't expose their history, so we track committed URLs.
  const stack = useRef<string[]>([]);
  const navigate = (u: string) => {
    if (url) stack.current.push(url);
    onNavigate(u);
  };
  const back = () => {
    const prev = stack.current.pop();
    if (prev !== undefined) onNavigate(prev);
  };

  const submit = async () => {
    const v = input.trim();
    if (!v) return;
    const target = normalize(v);
    navigate(
      target.includes("bing.com/search") || (await resolves(target))
        ? target
        : `https://www.bing.com/search?q=${encodeURIComponent(v)}`
    );
  };
  const reload = () => {
    const f = frameRef.current;
    // oxlint-disable-next-line no-self-assign -- reassigning src is the cross-origin-safe iframe reload
    if (f) f.src = f.src;
  };

  const toolbar = (
    <motion.div
      initial={{ opacity: 0, y: toolbarAt === "top" ? -16 : 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: "spring", stiffness: 300, damping: 26 }}
      className="pointer-events-none absolute inset-x-3 z-20"
      style={
        toolbarAt === "top"
          ? { top: "max(env(safe-area-inset-top), 10px)" }
          : { bottom: "max(env(safe-area-inset-bottom), 10px)" }
      }
    >
      <div className="glass pointer-events-auto flex items-center gap-1.5 rounded-full p-1.5">
        <LiquidButton
          variant="ghost"
          size="icon"
          aria-label="Back"
          className="h-9 w-9 shrink-0 rounded-full text-white/80 hover:bg-white/10 hover:text-white"
          onClick={back}
        >
          <ChevronLeft className="size-5" />
        </LiquidButton>
        <LiquidButton
          variant="ghost"
          size="icon"
          aria-label="Reload"
          className="h-9 w-9 shrink-0 rounded-full text-white/80 hover:bg-white/10 hover:text-white"
          onClick={reload}
        >
          <RotateCw className="size-4" />
        </LiquidButton>
        <form
          className="min-w-0 flex-1"
          onSubmit={(e) => {
            e.preventDefault();
            submit();
            (e.target as HTMLFormElement).querySelector("input")?.blur();
          }}
        >
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onFocus={(e) => e.target.select()}
            placeholder="Search or enter address"
            enterKeyHint="go"
            autoCapitalize="off"
            autoCorrect="off"
            spellCheck={false}
            inputMode="url"
            className="h-9 w-full rounded-full border border-white/10 bg-black/25 px-4 text-[15px] text-white/90 outline-none placeholder:text-white/35 focus:border-white/30 focus:bg-black/35"
          />
        </form>
        <LiquidButton
          variant="ghost"
          size="icon"
          aria-label="Clear"
          className="h-9 w-9 shrink-0 rounded-full text-white/80 hover:bg-white/10 hover:text-white"
          onClick={() => navigate("")}
        >
          <Home className="size-4" />
        </LiquidButton>
        <LiquidButton
          variant="ghost"
          size="icon"
          aria-label="Open in Safari"
          className="h-9 w-9 shrink-0 rounded-full text-white/80 hover:bg-white/10 hover:text-white"
          onClick={() => url && window.open(url, "_blank")}
        >
          <ExternalLink className="size-4" />
        </LiquidButton>
      </div>
    </motion.div>
  );

  return (
    <div className="relative h-full w-full overflow-hidden rounded-3xl bg-black">
      {url ? (
        <iframe
          ref={frameRef}
          src={url}
          title="Browser pane"
          className="h-full w-full border-0 bg-white"
          allow="fullscreen"
        />
      ) : (
        <div className="flex h-full w-full items-center justify-center bg-[radial-gradient(120%_100%_at_20%_0%,#1b1e3a_0%,#0a0a0f_55%),radial-gradient(80%_60%_at_90%_100%,#3b1d5a_0%,transparent_60%)] p-6">
          <LiquidGlassCard
            glassSize="sm"
            className="w-full max-w-xs rounded-3xl border-white/15"
          >
            <p className="mb-3 text-center text-sm font-medium text-white/70">
              Pick a site or type an address
            </p>
            <div className="grid grid-cols-2 gap-2">
              {QUICK_SITES.map((s, i) => (
                <motion.div
                  key={s.name}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.05 * i, type: "spring", stiffness: 260, damping: 22 }}
                >
                  <LiquidButton
                    variant="ghost"
                    className="w-full rounded-2xl border border-white/10 bg-white/5 text-[13px] text-white/85 hover:bg-white/15"
                    onClick={() => navigate(s.url)}
                  >
                    {s.name}
                  </LiquidButton>
                </motion.div>
              ))}
            </div>
            <p className="mt-3 text-center text-[11px] leading-snug text-white/35">
              Some sites block embedding — use ↗ to open them in Safari.
            </p>
          </LiquidGlassCard>
        </div>
      )}
      {toolbar}
    </div>
  );
}
