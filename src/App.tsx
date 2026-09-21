import { animate, motion } from "motion/react";
import { ArrowLeftRight, ArrowUpDown, Columns2, Rows2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Pane } from "@/Pane";
import { cn } from "@/lib/utils";

const STORAGE_KEY = "duoscreen.v1";
const MIN_SPLIT = 18;

interface Saved {
  urls: [string, string];
  split: number;
  horizontal: boolean;
}

function load(): Saved {
  try {
    return { urls: ["", ""], split: 50, horizontal: false, ...JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "{}") };
  } catch {
    return { urls: ["", ""], split: 50, horizontal: false };
  }
}

export default function App() {
  const [{ urls, split, horizontal }, setState] = useState<Saved>(load);
  const [dragging, setDragging] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ urls, split, horizontal }));
  }, [urls, split, horizontal]);

  const setUrl = (i: number) => (url: string) =>
    setState((s) => {
      const next: [string, string] = [...s.urls];
      next[i] = url;
      return { ...s, urls: next };
    });

  const swap = () => setState((s) => ({ ...s, urls: [s.urls[1], s.urls[0]] }));
  const rotate = () => setState((s) => ({ ...s, horizontal: !s.horizontal }));
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
  const RotateIcon = horizontal ? Rows2 : Columns2;

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
          "relative z-30 flex shrink-0 touch-none items-center justify-center",
          horizontal ? "w-5 cursor-col-resize" : "h-5 cursor-row-resize"
        )}
        onPointerDown={(e) => {
          (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
          setDragging(true);
        }}
      >
        <motion.div
          whileTap={{ scale: 1.12 }}
          className={cn(
            "glass glass-strong absolute flex items-center justify-center gap-1 rounded-full",
            horizontal ? "h-16 w-9 flex-col" : "h-9 w-16"
          )}
        >
          <button
            aria-label="Swap panes"
            className="rounded-full p-1 text-white/70 active:text-white"
            onClick={swap}
          >
            <SwapIcon className="size-3.5" />
          </button>
          <button
            aria-label="Reset split"
            className="rounded-full p-1 text-white/70 active:text-white"
            onClick={reset}
          >
            <span className="block h-0.5 w-3.5 rounded-full bg-current" />
          </button>
          <button
            aria-label="Rotate layout"
            className="rounded-full p-1 text-white/70 active:text-white"
            onClick={rotate}
          >
            <RotateIcon className="size-3.5" />
          </button>
        </motion.div>
      </div>

      <div style={{ flexBasis: `${100 - split}%` }} className="min-h-0 min-w-0">
        <Pane url={urls[1]} onNavigate={setUrl(1)} toolbarAt="bottom" />
      </div>
    </div>
  );
}
