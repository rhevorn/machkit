import React from "react";
import { createRoot } from "react-dom/client";
import "./styles.css";

function App() {
  return (
    <main className="workspace">
      <section className="hero">
        <span className="eyebrow">Sift · Web Tools</span>
        <h1>Embedded tool workspace</h1>
        <p>
          H5 tools live in isolated folders, share the native Sift appearance, and
          build into independent pages for WKWebView.
        </p>
      </section>

      <section className="empty-state" aria-labelledby="empty-title">
        <div className="tool-icon" aria-hidden="true">&lt;/&gt;</div>
        <div>
          <h2 id="empty-title">Ready for the next tool</h2>
          <p>Add a directory under <code>tools/</code> when its product scope is clear.</p>
        </div>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
