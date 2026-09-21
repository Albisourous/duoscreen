import { animate, motion } from "motion/react";
import { ArrowLeftRight, ArrowUpDown } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Pane } from "@/Pane";
import { cn } from "@/lib/utils";

const STORAGE_KEY = "duoscreen.v2";
const MIN_SPLIT = 18;

interface Saved {
  urls: [string, string];
  split: number;
}

function load(): Saved {
  try {
    return { urls: ["", ""], split: 50, ...JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "{}") };
  } catch {
    return { urls: ["", ""], split: 50 };
  }
}

/** Portrait → stacked panes (Duo-style); landscape → side-by-side. */
function useLandscape() {
  const [landscape, setLandscape] = useState(
    () => window.matchMedia("(orientation: landscape)").matches
  );
  useEffect(() => {
    const mq = window.matchMedia("(orientation: landscape)");
    const onChange = () => setLandscape(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);
  return landscape;
}

export default function App() {
  const [{ urls, split }, setState] = useState<Saved>(load);
  const horizontal = useLandscape();
  const [dragging, setDragging] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ urls, split }));
  }, [urls, split]);

  const setUrl = (i: number) => (url: string) =>
    setState((s) => {
      const next: [string, string] = [...s.urls];
      next[i] = url;
      return { ...s, urls: next };
    });

  const swap = () => setState((s) => ({ ...s, urls: [s.urls[1], s.urls[0]] }));
  const reset = () =>
    animate(split, 50, {
      type: "spring",
      stiffness: 300,
      damping: 30,
      onUpdate: (v) => setState((s) => ({ ...s, split: v })),
    });

  const onMove = (e: React.PointerEvent) => {
    if (!dragging || !containerRef.current) return;
    const r = containerRef.current.getBoundingClientRect();
    const pct = horizontal
      ? ((e.clientX - r.left) / r.width) * 100
      : ((e.clientY - r.top) / r.height) * 100;
    setState((s) => ({ ...s, split: Math.min(100 - MIN_SPLIT, Math.max(MIN_SPLIT, pct)) }));
  };

  const SwapIcon = horizontal ? ArrowLeftRight : ArrowUpDown;

  return (
    <div
      ref={containerRef}
      className={cn(
        "relative flex h-dvh w-full bg-[#0a0a0f]",
        horizontal ? "flex-row" : "flex-col",
        dragging && "dragging select-none"
      )}
      onPointerMove={onMove}
      onPointerUp={() => setDragging(false)}
      onPointerCancel={() => setDragging(false)}
    >
      <div style={{ flexBasis: `${split}%` }} className="min-h-0 min-w-0">
        <Pane url={urls[0]} onNavigate={setUrl(0)} toolbarAt="top" />
      </div>

      {/* Divider */}
      <div
        className={cn(
          "relative z-30 flex shrink-0 touch-none items-center justify-center bg-white/15",
          "before:absolute before:content-['']",
          horizontal
            ? "w-px cursor-col-resize before:-inset-x-3 before:inset-y-0"
            : "h-px cursor-row-resize before:-inset-y-3 before:inset-x-0"
        )}
        onPointerDown={(e) => {
          (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
          setDragging(true);
        }}
      >
        <motion.div
          whileTap={{ scale: 1.12 }}
          className={cn(
            "glass glass-strong absolute flex items-center justify-center gap-0.5 rounded-full",
            horizontal ? "h-16 w-10 flex-col" : "h-10 w-16"
          )}
        >
          <button
            aria-label="Swap panes"
            className="rounded-full p-1.5 text-white/70 active:text-white"
            onClick={swap}
          >
            <SwapIcon className="size-4" />
          </button>
          <button
            aria-label="Reset split"
            className="rounded-full p-1.5 text-white/70 active:text-white"
            onClick={reset}
          >
            <span className="block h-0.5 w-4 rounded-full bg-current" />
          </button>
        </motion.div>
      </div>

      <div style={{ flexBasis: `${100 - split}%` }} className="min-h-0 min-w-0">
        <Pane url={urls[1]} onNavigate={setUrl(1)} toolbarAt="bottom" />
      </div>
    </div>
  );
}
