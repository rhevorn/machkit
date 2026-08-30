import type { MachKitAppearance, MachKitPreferences } from "./types.js";

type BridgeParams = Record<string, unknown>;
type BridgeOptions = { timeout?: number };
type PreferenceListener = (preferences: MachKitPreferences) => void;

type PickFileOptions = { prompt?: string; accept?: string };
type PickFileResult = { path: string; name: string };

type SaveFileOptions = {
  name?: string;
  dataBase64?: string;
  mimeType?: string;
  timeout?: number;
};
type SaveFileResult = { path?: string; name: string };

const handlers = () => window.webkit?.messageHandlers;
const preferenceListeners = new Set<PreferenceListener>();
const DEFAULT_BRIDGE_TIMEOUT = 10_000;
const BROWSER_PREFS_KEY = "machkit:dev-preferences";
const ALLOWED_APPEARANCES = new Set<string>(["system", "light", "dark"]);

function readQueryPreferences(): Partial<MachKitPreferences> {
  if (typeof window === "undefined" || !window.location?.search) return {};
  try {
    const params = new URLSearchParams(window.location.search);
    return {
      locale: params.get("locale") || undefined,
      appearance: (params.get("appearance") as MachKitAppearance | null) || undefined,
    };
  } catch {
    return {};
  }
}

function readStoredBrowserPreferences(): Partial<MachKitPreferences> {
  if (typeof window === "undefined" || handlers()?.bridge) return {};
  try {
    const raw = window.localStorage?.getItem(BROWSER_PREFS_KEY);
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? (parsed as Partial<MachKitPreferences>) : {};
  } catch {
    return {};
  }
}

function normalizeAppearance(value: unknown, fallback: MachKitAppearance = "system"): MachKitAppearance {
  return ALLOWED_APPEARANCES.has(String(value)) ? (value as MachKitAppearance) : fallback;
}

function readBootstrapPreferences(): MachKitPreferences {
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

function applyAppearance(appearance: MachKitAppearance): void {
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

function syncBrowserDebugState(next: MachKitPreferences): void {
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

function publishPreferences(next: Partial<MachKitPreferences>): void {
  preferences = {
    locale: next.locale || preferences.locale || "en",
    appearance: normalizeAppearance(next.appearance, preferences.appearance || "system"),
  };
  window.__MACHKIT__ = Object.freeze({ ...preferences });
  applyAppearance(preferences.appearance);
  syncBrowserDebugState(preferences);
  preferenceListeners.forEach((listener) => listener(preferences));
}

function announceCopyResult(ok: boolean, error: string | null = null): void {
  window.dispatchEvent(new CustomEvent("machkit:copy-result", { detail: { ok, error } }));
}

applyAppearance(preferences.appearance);

window.__MACHKIT_APPLY_PREFERENCES__ = (next) => {
  if (!next || typeof next !== "object") return;
  publishPreferences(next);
};

export const machkit = Object.freeze({
  isEmbedded: Boolean(handlers()?.bridge),

  async request<T = unknown>(
    method: string,
    params: BridgeParams = {},
    { timeout = DEFAULT_BRIDGE_TIMEOUT }: BridgeOptions = {},
  ): Promise<T> {
    const handler = handlers()?.bridge;
    if (!handler || typeof handler.postMessage !== "function") {
      throw new Error("This operation is available in the MachKit app.");
    }

    let timeoutID = 0;
    let timedOut = false;
    const deadline = new Promise<never>((_, reject) => {
      timeoutID = window.setTimeout(() => {
        timedOut = true;
        reject(new Error(`The ${method} operation timed out.`));
      }, timeout);
    });

    try {
      return (await Promise.race([
        Promise.resolve(handler.postMessage({ protocolVersion: 1, method, params })) as Promise<T>,
        deadline,
      ])) as T;
    } catch (error) {
      if (timedOut && method === "curlLab.run") {
        try {
          await Promise.resolve(
            handler.postMessage({ protocolVersion: 1, method: "curlLab.cancel", params: {} }),
          );
        } catch {
          // Best-effort cancel after the waiter already timed out.
        }
      }
      throw error;
    } finally {
      window.clearTimeout(timeoutID);
    }
  },

  async copy(text: unknown): Promise<boolean> {
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

  async readClipboard(): Promise<string> {
    try {
      if (this.isEmbedded) {
        const result = await this.request<{ text?: string }>("clipboard.read");
        return typeof result?.text === "string" ? result.text : "";
      }
      if (!navigator.clipboard?.readText) return "";
      return await navigator.clipboard.readText();
    } catch {
      return "";
    }
  },

  fitContentHeight(height: number): Promise<boolean> {
    if (!Number.isFinite(height) || height <= 0 || !this.isEmbedded) return Promise.resolve(false);
    return this.request("window.fitContentHeight", { height: Math.ceil(height) })
      .then(() => true)
      .catch(() => false);
  },

  setWindowTitle(title: unknown): Promise<boolean> {
    const next = String(title ?? "");
    if (typeof document !== "undefined") {
      document.title = next;
    }
    return this.request("window.setTitle", { title: next })
      .then(() => true)
      .catch(() => false);
  },

  getPreferences(): MachKitPreferences {
    return preferences;
  },

  subscribePreferences(listener: PreferenceListener): () => void {
    preferenceListeners.add(listener);
    return () => {
      preferenceListeners.delete(listener);
    };
  },

  applyPreferences(next: Partial<MachKitPreferences>): void {
    publishPreferences(next);
  },

  hosts(action: string, payload: BridgeParams = {}): Promise<unknown> {
    if (!/^(load|save|apply)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported Hosts operation: ${action}`));
    }
    return this.request(`hosts.${action}`, payload);
  },

  portScan(action: string, payload: BridgeParams = {}, options: BridgeOptions = {}): Promise<unknown> {
    if (!/^(start|status|cancel)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported Port Scan operation: ${action}`));
    }
    return this.request(`portScan.${action}`, payload, {
      timeout: options.timeout ?? 10_000,
    });
  },

  curlLab(action: string, payload: BridgeParams = {}, options: BridgeOptions = {}): Promise<unknown> {
    if (!/^(run|cancel)$/.test(action)) {
      return Promise.reject(new Error(`Unsupported cURL Lab operation: ${action}`));
    }
    return this.request(`curlLab.${action}`, payload, {
      timeout: options.timeout ?? (action === "cancel" ? 10_000 : 45_000),
    });
  },

  async pickFile(options: PickFileOptions = {}): Promise<PickFileResult | null> {
    if (this.isEmbedded) {
      const result = await this.request<{ canceled?: boolean; path?: string; name?: string }>("files.pick", {
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
        resolve({ path: file.name, name: file.name });
      });
      input.addEventListener("cancel", () => resolve(null));
      input.click();
    });
  },

  async saveFile(options: SaveFileOptions = {}): Promise<SaveFileResult | null> {
    const name = String(options.name ?? "download.bin").replace(/[/\\]/g, "_");
    const dataBase64 = String(options.dataBase64 ?? "");
    if (!name || !dataBase64) return null;

    if (this.isEmbedded) {
      const result = await this.request<{ canceled?: boolean; path?: string; name?: string }>(
        "files.save",
        { name, dataBase64 },
        { timeout: options.timeout ?? 120_000 },
      );
      if (!result || result.canceled) return null;
      return {
        path: typeof result.path === "string" ? result.path : undefined,
        name: typeof result.name === "string" ? result.name : name,
      };
    }

    const binary = atob(dataBase64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    const mime =
      typeof options.mimeType === "string" && options.mimeType
        ? options.mimeType
        : "application/octet-stream";
    const url = URL.createObjectURL(new Blob([bytes], { type: mime }));
    const link = document.createElement("a");
    link.href = url;
    link.download = name;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    return { name };
  },

  async getItem(key: unknown): Promise<string | null> {
    const storageKey = String(key ?? "");
    if (this.isEmbedded) {
      const result = await this.request<{ value?: string | null }>("storage.get", { key: storageKey });
      return typeof result?.value === "string" ? result.value : null;
    }
    try {
      return window.localStorage?.getItem(`machkit:${storageKey}`) ?? null;
    } catch {
      return null;
    }
  },

  async setItem(key: unknown, value: unknown): Promise<boolean> {
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

export type Machkit = typeof machkit;

if (typeof window !== "undefined" && !machkit.isEmbedded) {
  window.machkit = machkit;
  syncBrowserDebugState(preferences);
}
