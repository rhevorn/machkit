import React, { useEffect, useRef, useState, type ErrorInfo, type PointerEvent as ReactPointerEvent, type PropsWithChildren, type ReactNode } from "react";
import { createRoot, type Root } from "react-dom/client";
import { supportedLocales } from "@/i18n-catalog.js";
import { resolveLocale, useLocale } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { runtimeMessages } from "@/runtime/runtime-messages.js";
import type { MachKitAppearance } from "@/runtime/types.js";
import { Button } from "@/ui/index.js";
import "@/ui/ui.css";

type ToolErrorBoundaryProps = PropsWithChildren<{ name: string }>;
type ToolErrorBoundaryState = { error: Error | null };

function ToolCrashView() {
  const locale = useLocale();
  const text = runtimeMessages[locale as keyof typeof runtimeMessages] ?? runtimeMessages.en;

  return (
    <main className="grid min-h-full place-items-center bg-surface p-8 font-sans text-foreground">
      <section className="max-w-md text-center" role="alert" aria-live="assertive">
        <h1 className="text-base font-semibold">{text.errorTitle}</h1>
        <p className="mt-2 text-xs leading-relaxed text-secondary">{text.errorDescription}</p>
        <Button className="mt-4" onClick={() => window.location.reload()}>
          {text.reload}
        </Button>
      </section>
    </main>
  );
}

class ToolErrorBoundary extends React.Component<ToolErrorBoundaryProps, ToolErrorBoundaryState> {
  constructor(props: ToolErrorBoundaryProps) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error: Error): ToolErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`Unable to render ${this.props.name}.`, error, info);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return <ToolCrashView />;
  }
}

const appearanceOptions: Array<{ value: MachKitAppearance; label: string }> = [
  { value: "system", label: "System" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
];

const DOCK_LAYOUT_KEY = "machkit:dev-dock-layout";
const ROOT_KEY = "__machkitReactRoot";

type RootHost = HTMLElement & { [ROOT_KEY]?: Root };

type DockLayout = {
  x: number;
  y: number;
  collapsed: boolean;
};

type DockDragState = {
  pointerId: number;
  offsetX: number;
  offsetY: number;
  startX: number;
  startY: number;
  moved: boolean;
};

function renderInto(container: RootHost, node: ReactNode): Root {
  let root = container[ROOT_KEY];
  if (!root) {
    root = createRoot(container);
    container[ROOT_KEY] = root;
  }
  root.render(node);
  return root;
}

function homeHref(): string | null {
  const marker = "/tools/";
  const index = window.location.pathname.indexOf(marker);
  if (index < 0) return null;
  const url = new URL(window.location.href);
  url.pathname = `${url.pathname.slice(0, index)}/` || "/";
  return `${url.pathname}${url.search}`;
}

function defaultDockLayout(): DockLayout {
  return {
    x: Math.max(16, window.innerWidth / 2 - 160),
    y: Math.max(16, window.innerHeight - 72),
    collapsed: false,
  };
}

function readDockLayout(): DockLayout {
  try {
    const raw = window.localStorage?.getItem(DOCK_LAYOUT_KEY);
    if (!raw) return defaultDockLayout();
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return defaultDockLayout();
    const record = parsed as Partial<DockLayout>;
    return {
      x: Number.isFinite(record.x) ? Number(record.x) : defaultDockLayout().x,
      y: Number.isFinite(record.y) ? Number(record.y) : defaultDockLayout().y,
      collapsed: record.collapsed === true,
    };
  } catch {
    return defaultDockLayout();
  }
}

function clampDockPosition(x: number, y: number, width: number, height: number): { x: number; y: number } {
  const maxX = Math.max(8, window.innerWidth - width - 8);
  const maxY = Math.max(8, window.innerHeight - height - 8);
  return {
    x: Math.min(maxX, Math.max(8, x)),
    y: Math.min(maxY, Math.max(8, y)),
  };
}

function measureToolViewportSize(): { width: number; height: number } {
  return {
    width: Math.ceil(window.innerWidth),
    height: Math.ceil(window.innerHeight),
  };
}

function DevPreferencesDock() {
  useLocale();
  const preferences = machkit.getPreferences();
  const panelRef = useRef<HTMLElement | null>(null);
  const dragRef = useRef<DockDragState | null>(null);
  const layoutRef = useRef<DockLayout>(readDockLayout());
  const suppressClickRef = useRef(false);
  const [layout, setLayout] = useState<DockLayout>(() => layoutRef.current);
  const [contentSize, setContentSize] = useState(() => measureToolViewportSize());
  const [copiedField, setCopiedField] = useState<"height" | "size" | null>(null);
  const homeLink = homeHref();

  // Keep ref aligned with React state, but never while a drag owns the position.
  if (!dragRef.current) {
    layoutRef.current = layout;
  }

  useEffect(() => {
    try {
      window.localStorage?.setItem(DOCK_LAYOUT_KEY, JSON.stringify(layout));
    } catch {
      // Ignore quota / private-mode failures.
    }
  }, [layout]);

  useEffect(() => {
    const keepInViewport = () => {
      if (dragRef.current) return;
      const node = panelRef.current;
      if (!node) return;
      const current = layoutRef.current;
      const next = clampDockPosition(current.x, current.y, node.offsetWidth, node.offsetHeight);
      if (next.x !== current.x || next.y !== current.y) {
        setLayout((value) => ({ ...value, ...next }));
      }
    };
    window.addEventListener("resize", keepInViewport);
    keepInViewport();
    return () => window.removeEventListener("resize", keepInViewport);
  }, [layout.collapsed]);

  useEffect(() => {
    let frame = 0;
    const update = () => {
      if (dragRef.current) return;
      window.cancelAnimationFrame(frame);
      frame = window.requestAnimationFrame(() => {
        setContentSize(measureToolViewportSize());
      });
    };
    update();
    const root = document.getElementById("root");
    const observer = typeof ResizeObserver !== "undefined" ? new ResizeObserver(update) : null;
    if (root && observer) observer.observe(root);
    window.addEventListener("resize", update);
    document.fonts?.ready.then(update);
    return () => {
      window.cancelAnimationFrame(frame);
      observer?.disconnect();
      window.removeEventListener("resize", update);
    };
  }, []);

  useEffect(() => {
    if (!copiedField) return undefined;
    const timer = window.setTimeout(() => setCopiedField(null), 1200);
    return () => window.clearTimeout(timer);
  }, [copiedField]);

  const copyMetric = async (field: "height" | "size") => {
    const text = field === "height"
      ? String(contentSize.height)
      : `${contentSize.width}×${contentSize.height}`;
    try {
      await navigator.clipboard.writeText(text);
      setCopiedField(field);
    } catch {
      // Clipboard may be blocked in some browser contexts.
    }
  };

  const beginDrag = (event: ReactPointerEvent<HTMLElement>) => {
    // Mouse: primary button only. Touch/pen: button is often 0 or -1.
    if (event.pointerType === "mouse" && event.button !== 0) return;
    const node = panelRef.current;
    if (!node || dragRef.current) return;
    event.preventDefault();
    event.stopPropagation();

    const origin = layoutRef.current;
    const drag: DockDragState = {
      pointerId: event.pointerId,
      offsetX: event.clientX - origin.x,
      offsetY: event.clientY - origin.y,
      startX: origin.x,
      startY: origin.y,
      moved: false,
    };
    dragRef.current = drag;

    // Capture on the moving panel so touch doesn't scroll the page / lose the gesture.
    try {
      node.setPointerCapture(event.pointerId);
    } catch {
      // Some browsers reject capture on the wrong target; window listeners still work.
    }
    const previousTouchAction = node.style.touchAction;
    const previousUserSelect = document.documentElement.style.userSelect;
    node.style.touchAction = "none";
    document.documentElement.style.userSelect = "none";

    const onMove = (moveEvent: PointerEvent) => {
      if (moveEvent.pointerId !== drag.pointerId) return;
      moveEvent.preventDefault();
      const next = clampDockPosition(
        moveEvent.clientX - drag.offsetX,
        moveEvent.clientY - drag.offsetY,
        node.offsetWidth,
        node.offsetHeight,
      );
      if (Math.abs(next.x - drag.startX) > 2 || Math.abs(next.y - drag.startY) > 2) {
        drag.moved = true;
      }
      node.style.left = `${next.x}px`;
      node.style.top = `${next.y}px`;
      layoutRef.current = { ...layoutRef.current, x: next.x, y: next.y };
    };

    const onUp = (upEvent: PointerEvent) => {
      if (upEvent.pointerId !== drag.pointerId) return;
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
      try {
        if (node.hasPointerCapture(upEvent.pointerId)) {
          node.releasePointerCapture(upEvent.pointerId);
        }
      } catch {
        // Ignore.
      }
      node.style.touchAction = previousTouchAction;
      document.documentElement.style.userSelect = previousUserSelect;
      dragRef.current = null;
      if (drag.moved) suppressClickRef.current = true;
      setLayout((current) => ({
        ...current,
        x: layoutRef.current.x,
        y: layoutRef.current.y,
      }));
    };

    // passive: false so preventDefault can block touch page scroll while dragging.
    window.addEventListener("pointermove", onMove, { passive: false });
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
  };

  if (layout.collapsed) {
    return (
      <button
        ref={panelRef as React.RefObject<HTMLButtonElement>}
        type="button"
        className="fixed z-[1000] flex h-8 cursor-grab items-center rounded-full border border-border bg-surface/95 px-3 text-[11px] font-semibold text-secondary shadow-popover backdrop-blur-sm active:cursor-grabbing"
        style={{ left: layout.x, top: layout.y, touchAction: "none" }}
        title="Show language and theme controls"
        data-dock-drag=""
        onPointerDown={beginDrag}
        onClick={() => {
          if (suppressClickRef.current) {
            suppressClickRef.current = false;
            return;
          }
          setLayout((current) => ({ ...current, collapsed: false }));
        }}
      >
        Dev · {contentSize.height}
      </button>
    );
  }

  return (
    <div
      ref={panelRef as React.RefObject<HTMLDivElement>}
      className="fixed z-[1000] flex max-w-[calc(100vw-16px)] flex-wrap items-center gap-2 rounded-panel border border-border bg-surface/95 px-2 py-2 shadow-popover backdrop-blur-sm"
      style={{ left: layout.x, top: layout.y, touchAction: "none" }}
      onPointerDown={(event) => {
        const target = event.target as HTMLElement | null;
        if (!target) return;
        // Touch: allow dragging from chrome padding; ignore real controls.
        if (target.closest("select, a, label, input, textarea, button:not([data-dock-drag])")) return;
        beginDrag(event);
      }}
    >
      <button
        type="button"
        data-dock-drag=""
        className="flex h-7 cursor-grab items-center gap-1 rounded-control px-2 text-[10px] font-semibold tracking-wide text-tertiary uppercase active:cursor-grabbing"
        style={{ touchAction: "none" }}
        title="Drag to move"
        onPointerDown={beginDrag}
      >
        <span aria-hidden="true">⋮⋮</span>
        Dev
      </button>
      <label className="flex items-center gap-1.5 text-[11px] text-secondary">
        <span>Lang</span>
        <select
          className="h-7 rounded-control border border-border bg-field px-2 text-[11px] text-foreground outline-none"
          value={resolveLocale(preferences.locale)}
          onChange={(event) => machkit.applyPreferences({ locale: event.target.value })}
        >
          {supportedLocales.map((value) => (
            <option key={value} value={value}>{value}</option>
          ))}
        </select>
      </label>
      <label className="flex items-center gap-1.5 text-[11px] text-secondary">
        <span>Theme</span>
        <select
          className="h-7 rounded-control border border-border bg-field px-2 text-[11px] text-foreground outline-none"
          value={preferences.appearance || "system"}
          onChange={(event) =>
            machkit.applyPreferences({ appearance: event.target.value as MachKitAppearance })
          }
        >
          {appearanceOptions.map((option) => (
            <option key={option.value} value={option.value}>{option.label}</option>
          ))}
        </select>
      </label>
      <button
        type="button"
        className="h-7 rounded-control border border-border bg-field px-2 font-mono text-[11px] text-foreground hover:bg-muted"
        title="Copy viewport height for DeveloperTool.height"
        onClick={() => void copyMetric("height")}
      >
        {copiedField === "height" ? "Copied" : `H ${contentSize.height}`}
      </button>
      <button
        type="button"
        className="h-7 rounded-control px-2 font-mono text-[11px] text-secondary hover:bg-muted hover:text-foreground"
        title="Copy viewport size (width×height) for DeveloperTool"
        onClick={() => void copyMetric("size")}
      >
        {copiedField === "size" ? "Copied" : `${contentSize.width}×${contentSize.height}`}
      </button>
      {homeLink ? (
        <a
          href={homeLink}
          className="h-7 rounded-control px-2 text-[11px] leading-7 text-secondary no-underline hover:bg-muted hover:text-foreground"
        >
          Home
        </a>
      ) : null}
      <button
        type="button"
        className="ml-auto h-7 rounded-control px-2 text-[11px] text-secondary hover:bg-muted hover:text-foreground"
        title="Hide controls"
        onClick={() => setLayout((current) => ({ ...current, collapsed: true }))}
      >
        Hide
      </button>
    </div>
  );
}

function mountDevPreferencesDock() {
  if (machkit.isEmbedded || typeof document === "undefined") return;
  const hostID = "machkit-dev-preferences";
  let host = document.getElementById(hostID);
  if (!host) {
    host = document.createElement("div");
    host.id = hostID;
    document.body.append(host);
  }
  renderInto(host, <DevPreferencesDock />);
}

export type MountToolOptions = {
  name?: string;
  strict?: boolean;
};

export function mountTool(element: ReactNode, { name = "tool", strict = true }: MountToolOptions = {}) {
  const rootElement = document.getElementById("root");
  if (!rootElement) throw new Error(`Unable to mount ${name}: #root was not found.`);

  machkit.applyPreferences({
    locale: resolveLocale(machkit.getPreferences().locale),
    appearance: machkit.getPreferences().appearance,
  });

  const content = <ToolErrorBoundary name={name}>{element}</ToolErrorBoundary>;
  renderInto(rootElement, strict ? <React.StrictMode>{content}</React.StrictMode> : content);
  mountDevPreferencesDock();
}
