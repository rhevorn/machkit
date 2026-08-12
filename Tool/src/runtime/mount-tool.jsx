import React from "react";
import { createRoot } from "react-dom/client";

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

export function mountTool(element, { name = "tool", strict = true } = {}) {
  const rootElement = document.getElementById("root");
  if (!rootElement) throw new Error(`Unable to mount ${name}: #root was not found.`);
  const content = <ToolErrorBoundary name={name}>{element}</ToolErrorBoundary>;
  createRoot(rootElement).render(strict ? <React.StrictMode>{content}</React.StrictMode> : content);
}
