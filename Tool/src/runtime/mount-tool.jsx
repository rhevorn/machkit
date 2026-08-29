import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { supportedLocales } from "@/i18n-catalog.js";
import { resolveLocale, useLocale } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import "@/ui/ui.css";

class ToolErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error(`Unable to render ${this.props.name}.`, error, info);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <main className="grid min-h-full place-items-center bg-surface p-8 font-sans text-foreground">
        <section className="max-w-md text-center">
          <h1 className="text-base font-semibold">This tool could not be opened</h1>
          <p className="mt-2 text-xs leading-relaxed text-secondary">{this.state.error.message || "An unexpected error occurred."}</p>
          <button type="button" className="mt-4 h-9 rounded-control bg-accent px-4 text-xs font-medium text-white" onClick={() => window.location.reload()}>Reload</button>
        </section>
      </main>
    );
  }
}

const appearanceOptions = [
  { value: "system", label: "System" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
];

const DOCK_LAYOUT_KEY = "machkit:dev-dock-layout";
const reactRoots = new WeakMap();

function renderInto(container, node) {
  let root = reactRoots.get(container);
  if (!root) {
    root = createRoot(container);
    reactRoots.set(container, root);
  }
  root.render(node);
  return root;
}

function homeHref() {
  const marker = "/tools/";
  const index = window.location.pathname.indexOf(marker);
  if (index < 0) return null;
  const url = new URL(window.location.href);
  url.pathname = `${url.pathname.slice(0, index)}/` || "/";
  return `${url.pathname}${url.search}`;
}

function defaultDockLayout() {
  return {
    x: Math.max(16, window.innerWidth / 2 - 160),
    y: Math.max(16, window.innerHeight - 72),
    collapsed: false,
  };
}

function readDockLayout() {
  try {
    const raw = window.localStorage?.getItem(DOCK_LAYOUT_KEY);
    if (!raw) return defaultDockLayout();
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return defaultDockLayout();
    return {
      x: Number.isFinite(parsed.x) ? parsed.x : defaultDockLayout().x,
      y: Number.isFinite(parsed.y) ? parsed.y : defaultDockLayout().y,
      collapsed: parsed.collapsed === true,
    };
  } catch {
    return defaultDockLayout();
  }
}

function clampDockPosition(x, y, width, height) {
  const maxX = Math.max(8, window.innerWidth - width - 8);
  const maxY = Math.max(8, window.innerHeight - height - 8);
  return {
    x: Math.min(maxX, Math.max(8, x)),
    y: Math.min(maxY, Math.max(8, y)),
  };
}

function DevPreferencesDock() {
  useLocale();
  const preferences = machkit.getPreferences();
  const panelRef = useRef(null);
  const dragRef = useRef(null);
  const suppressClickRef = useRef(false);
  const [layout, setLayout] = useState(() => readDockLayout());

  useEffect(() => {
    try {
      window.localStorage?.setItem(DOCK_LAYOUT_KEY, JSON.stringify(layout));
    } catch {
      // Ignore quota / private-mode failures.
    }
  }, [layout]);

  useEffect(() => {
    const keepInViewport = () => {
      const node = panelRef.current;
      if (!node) return;
      const next = clampDockPosition(layout.x, layout.y, node.offsetWidth, node.offsetHeight);
      if (next.x !== layout.x || next.y !== layout.y) {
        setLayout((current) => ({ ...current, ...next }));
      }
    };
    window.addEventListener("resize", keepInViewport);
    keepInViewport();
    return () => window.removeEventListener("resize", keepInViewport);
  }, [layout.collapsed, layout.x, layout.y]);

  const beginDrag = (event) => {
    if (event.button !== 0) return;
    const node = panelRef.current;
    if (!node) return;
    event.preventDefault();
    dragRef.current = {
      pointerId: event.pointerId,
      offsetX: event.clientX - layout.x,
      offsetY: event.clientY - layout.y,
      moved: false,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const onDragMove = (event) => {
    const drag = dragRef.current;
    const node = panelRef.current;
    if (!drag || drag.pointerId !== event.pointerId || !node) return;
    const next = clampDockPosition(
      event.clientX - drag.offsetX,
      event.clientY - drag.offsetY,
      node.offsetWidth,
      node.offsetHeight,
    );
    if (Math.abs(next.x - layout.x) > 2 || Math.abs(next.y - layout.y) > 2) drag.moved = true;
    setLayout((current) => ({ ...current, ...next }));
  };

  const endDrag = (event) => {
    const drag = dragRef.current;
    if (!drag || drag.pointerId !== event.pointerId) return;
    if (drag.moved) suppressClickRef.current = true;
    dragRef.current = null;
    try {
      event.currentTarget.releasePointerCapture(event.pointerId);
    } catch {
      // Ignore if capture was already released.
    }
  };

  if (layout.collapsed) {
    return (
      <button
        ref={panelRef}
        type="button"
        className="fixed z-[1000] flex h-8 cursor-grab items-center rounded-full border border-border bg-surface/95 px-3 text-[11px] font-semibold text-secondary shadow-popover backdrop-blur-sm active:cursor-grabbing"
        style={{ left: layout.x, top: layout.y }}
        title="Show language and theme controls"
        onPointerDown={beginDrag}
        onPointerMove={onDragMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onClick={() => {
          if (suppressClickRef.current) {
            suppressClickRef.current = false;
            return;
          }
          setLayout((current) => ({ ...current, collapsed: false }));
        }}
      >
        Dev
      </button>
    );
  }

  return (
    <div
      ref={panelRef}
      className="fixed z-[1000] flex max-w-[calc(100vw-16px)] flex-wrap items-center gap-2 rounded-panel border border-border bg-surface/95 px-2 py-2 shadow-popover backdrop-blur-sm"
      style={{ left: layout.x, top: layout.y }}
    >
      <button
        type="button"
        className="flex h-7 cursor-grab items-center gap-1 rounded-control px-2 text-[10px] font-semibold tracking-wide text-tertiary uppercase active:cursor-grabbing"
        title="Drag to move"
        onPointerDown={beginDrag}
        onPointerMove={onDragMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
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
          onChange={(event) => machkit.applyPreferences({ appearance: event.target.value })}
        >
          {appearanceOptions.map((option) => (
            <option key={option.value} value={option.value}>{option.label}</option>
          ))}
        </select>
      </label>
      {homeHref() ? (
        <a
          href={homeHref()}
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

export function mountTool(element, { name = "tool", strict = true } = {}) {
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
