import React from "react";
import { createRoot, hydrateRoot } from "react-dom/client";
import { App } from "./App.jsx";
import "./styles.css";

const rootElement = document.getElementById("root");
const app = (
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

function alignLocationHash() {
  const rawID = window.location.hash.slice(1);
  let id = rawID;
  try {
    id = decodeURIComponent(rawID);
  } catch {
    // Keep the raw fragment when it contains an incomplete escape sequence.
  }
  const target = id ? document.getElementById(id) : null;
  if (!target) return;

  const documentElement = document.documentElement;
  const scrollPadding = Number.parseFloat(getComputedStyle(documentElement).scrollPaddingTop) || 0;
  const top = target.getBoundingClientRect().top + window.scrollY - scrollPadding;
  const previousBehavior = documentElement.style.scrollBehavior;
  documentElement.style.scrollBehavior = "auto";
  window.scrollTo(0, top);
  documentElement.style.scrollBehavior = previousBehavior;
}

if (rootElement.querySelector(".seo-fallback")) {
  createRoot(rootElement).render(app);
} else {
  hydrateRoot(rootElement, app);
}

requestAnimationFrame(() => {
  alignLocationHash();
  document.documentElement.removeAttribute("data-anchor-pending");
});
window.addEventListener("load", alignLocationHash, { once: true });
document.fonts?.ready.then(alignLocationHash);
