const handlers = () => window.webkit?.messageHandlers;
const preferenceListeners = new Set();
const DEFAULT_BRIDGE_TIMEOUT = 10_000;

function readBootstrapPreferences() {
  return {
    locale: window.__SIFT__?.locale || navigator.language || "en",
    appearance: window.__SIFT__?.appearance || "system",
  };
}

let preferences = readBootstrapPreferences();

function applyAppearance(appearance) {
  if (typeof document === "undefined") return;
  const root = document.documentElement;
  if (appearance === "light" || appearance === "dark") {
    root.dataset.appearance = appearance;
    root.style.colorScheme = appearance;
  } else {
    delete root.dataset.appearance;
    root.style.colorScheme = "";
  }
}

function publishPreferences(next) {
  preferences = {
    locale: next.locale || preferences.locale || "en",
    appearance: next.appearance || preferences.appearance || "system",
  };
  window.__SIFT__ = Object.freeze({ ...preferences });
  applyAppearance(preferences.appearance);
  preferenceListeners.forEach((listener) => listener(preferences));
}

function announceCopyResult(ok, error = null) {
  window.dispatchEvent(new CustomEvent("sift:copy-result", { detail: { ok, error } }));
}

applyAppearance(preferences.appearance);

window.__SIFT_APPLY_PREFERENCES__ = (next) => {
  if (!next || typeof next !== "object") return;
  publishPreferences(next);
};

export const sift = Object.freeze({
  isEmbedded: Boolean(handlers()?.bridge),

  async request(method, params = {}, { timeout = DEFAULT_BRIDGE_TIMEOUT } = {}) {
    const handler = handlers()?.bridge;
    if (!handler || typeof handler.postMessage !== "function") {
      throw new Error("This operation is available in the Sift app.");
    }

    let timeoutID = 0;
    const deadline = new Promise((_, reject) => {
      timeoutID = window.setTimeout(
        () => reject(new Error(`The ${method} operation timed out.`)),
        timeout,
      );
    });

    try {
      return await Promise.race([
        Promise.resolve(handler.postMessage({ protocolVersion: 1, method, params })),
        deadline,
      ]);
    } finally {
      window.clearTimeout(timeoutID);
    }
  },

  async copy(text) {
    try {
      if (this.isEmbedded) {
        await this.request("clipboard.copy", { text: String(text ?? "") });
      } else {
        await navigator.clipboard.writeText(String(text ?? ""));
      }
      announceCopyResult(true);
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unable to copy.";
      announceCopyResult(false, message);
      return false;
    }
  },

  fitContentHeight(height) {
    if (!Number.isFinite(height) || height <= 0 || !this.isEmbedded) return Promise.resolve(false);
    return this.request("window.fitContentHeight", { height: Math.ceil(height) })
      .then(() => true)
      .catch(() => false);
  },

  getPreferences() {
    return preferences;
  },

  subscribePreferences(listener) {
    preferenceListeners.add(listener);
    return () => preferenceListeners.delete(listener);
  },

  applyPreferences(next) {
    publishPreferences(next);
  },

  hosts(action, payload = {}) {
    if (!/^(load|save|activate)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported Hosts operation: ${action}`));
    }
    return this.request(`hosts.${action}`, payload);
  },
});
