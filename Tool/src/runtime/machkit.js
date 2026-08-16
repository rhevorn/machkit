const handlers = () => window.webkit?.messageHandlers;
const preferenceListeners = new Set();
const DEFAULT_BRIDGE_TIMEOUT = 10_000;
const BROWSER_PREFS_KEY = "machkit:dev-preferences";
const ALLOWED_APPEARANCES = new Set(["system", "light", "dark"]);

function readQueryPreferences() {
  if (typeof window === "undefined" || !window.location?.search) return {};
  try {
    const params = new URLSearchParams(window.location.search);
    return {
      locale: params.get("locale") || undefined,
      appearance: params.get("appearance") || undefined,
    };
  } catch {
    return {};
  }
}

function readStoredBrowserPreferences() {
  if (typeof window === "undefined" || handlers()?.bridge) return {};
  try {
    const raw = window.localStorage?.getItem(BROWSER_PREFS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function normalizeAppearance(value, fallback = "system") {
  return ALLOWED_APPEARANCES.has(value) ? value : fallback;
}

function readBootstrapPreferences() {
  const query = readQueryPreferences();
  const stored = readStoredBrowserPreferences();
  return {
    locale: query.locale || window.__MACHKIT__?.locale || stored.locale || navigator.language || "en",
    appearance: normalizeAppearance(
      query.appearance || window.__MACHKIT__?.appearance || stored.appearance,
      "system",
    ),
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

function syncBrowserDebugState(next) {
  if (typeof window === "undefined" || handlers()?.bridge) return;
  try {
    window.localStorage?.setItem(
      BROWSER_PREFS_KEY,
      JSON.stringify({ locale: next.locale, appearance: next.appearance }),
    );
  } catch {
    // Ignore quota / private-mode failures.
  }

  try {
    const url = new URL(window.location.href);
    url.searchParams.set("locale", next.locale);
    url.searchParams.set("appearance", next.appearance);
    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
  } catch {
    // Ignore environments without History API.
  }
}

function publishPreferences(next) {
  preferences = {
    locale: next.locale || preferences.locale || "en",
    appearance: normalizeAppearance(next.appearance, preferences.appearance || "system"),
  };
  window.__MACHKIT__ = Object.freeze({ ...preferences });
  applyAppearance(preferences.appearance);
  syncBrowserDebugState(preferences);
  preferenceListeners.forEach((listener) => listener(preferences));
}

function announceCopyResult(ok, error = null) {
  window.dispatchEvent(new CustomEvent("machkit:copy-result", { detail: { ok, error } }));
}

applyAppearance(preferences.appearance);

window.__MACHKIT_APPLY_PREFERENCES__ = (next) => {
  if (!next || typeof next !== "object") return;
  publishPreferences(next);
};

export const machkit = Object.freeze({
  isEmbedded: Boolean(handlers()?.bridge),

  async request(method, params = {}, { timeout = DEFAULT_BRIDGE_TIMEOUT } = {}) {
    const handler = handlers()?.bridge;
    if (!handler || typeof handler.postMessage !== "function") {
      throw new Error("This operation is available in the MachKit app.");
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

  connectionTrace(action, payload = {}, options = {}) {
    if (!/^(probe)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported Connection Trace operation: ${action}`));
    }
    return this.request(`connectionTrace.${action}`, payload, {
      timeout: options.timeout ?? 20_000,
    });
  },

  portScan(action, payload = {}, options = {}) {
    if (!/^(start|status|cancel)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported Port Scan operation: ${action}`));
    }
    return this.request(`portScan.${action}`, payload, {
      timeout: options.timeout ?? 10_000,
    });
  },

  curlLab(action, payload = {}, options = {}) {
    if (!/^(run)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported cURL Lab operation: ${action}`));
    }
    return this.request(`curlLab.${action}`, payload, {
      timeout: options.timeout ?? 45_000,
    });
  },

  /**
   * Opens a native/browser file picker.
   * @returns {Promise<{ path: string, name: string } | null>}
   */
  async pickFile(options = {}) {
    if (this.isEmbedded) {
      const result = await this.request("files.pick", {
        prompt: typeof options.prompt === "string" ? options.prompt : undefined,
      });
      if (!result || result.canceled) return null;
      const path = typeof result.path === "string" ? result.path : "";
      const name = typeof result.name === "string" ? result.name : path.split("/").pop() || "";
      if (!path) return null;
      return { path, name };
    }

    return new Promise((resolve) => {
      const input = document.createElement("input");
      input.type = "file";
      if (typeof options.accept === "string" && options.accept) {
        input.accept = options.accept;
      }
      input.addEventListener("change", () => {
        const file = input.files?.[0];
        if (!file) {
          resolve(null);
          return;
        }
        // Browsers hide the real path; keep the name so the form still works.
        resolve({ path: file.name, name: file.name });
      });
      input.addEventListener("cancel", () => resolve(null));
      input.click();
    });
  },

  async getItem(key) {
    const storageKey = String(key ?? "");
    if (this.isEmbedded) {
      const result = await this.request("storage.get", { key: storageKey });
      return typeof result?.value === "string" ? result.value : null;
    }
    try {
      return window.localStorage?.getItem(`machkit:${storageKey}`) ?? null;
    } catch {
      return null;
    }
  },

  async setItem(key, value) {
    const storageKey = String(key ?? "");
    const storageValue = String(value ?? "");
    if (this.isEmbedded) {
      await this.request("storage.set", { key: storageKey, value: storageValue });
      return true;
    }
    try {
      window.localStorage?.setItem(`machkit:${storageKey}`, storageValue);
      return true;
    } catch {
      return false;
    }
  },
});

if (typeof window !== "undefined" && !machkit.isEmbedded) {
  window.machkit = machkit;
  syncBrowserDebugState(preferences);
}
