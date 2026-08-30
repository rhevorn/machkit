import test from "node:test";
import assert from "node:assert/strict";
import type { MachKitBridgeHandler, MachKitPreferences } from "./types.js";

type MockCopyEvent = { type: string; detail?: { ok?: boolean; error?: string | null } };
type BridgeRequest = Parameters<MachKitBridgeHandler["postMessage"]>[0];
type BridgeResponse = unknown;

const events: MockCopyEvent[] = [];
let postMessage: (request: BridgeRequest) => Promise<BridgeResponse> = () =>
  Promise.resolve({ ok: true });

class MockCustomEvent<T = unknown> {
  type: string;
  detail: T | undefined;

  constructor(type: string, options: { detail?: T } = {}) {
    this.type = type;
    this.detail = options.detail;
  }
}

(globalThis as { CustomEvent: typeof MockCustomEvent }).CustomEvent = MockCustomEvent;

const mockDocumentElement = {
  dataset: {} as Record<string, string | undefined>,
  style: { colorScheme: "" } as { colorScheme: string },
};

(globalThis as { window: Window }).window = {
  __MACHKIT__: { locale: "en", appearance: "system" },
  webkit: {
    messageHandlers: {
      bridge: {
        postMessage: (request: BridgeRequest) => postMessage(request),
      },
    },
  },
  setTimeout,
  clearTimeout,
  dispatchEvent: ((event: MockCopyEvent) => {
    events.push(event);
    return true;
  }) as Window["dispatchEvent"],
} as unknown as Window;

(globalThis as { document: Document }).document = {
  documentElement: mockDocumentElement,
} as unknown as Document;

Object.defineProperty(globalThis, "navigator", {
  configurable: true,
  value: { language: "en" },
});

const { machkit } = await import("./machkit.js");

test("native requests carry a versioned method contract", async () => {
  postMessage = async (request) => {
    assert.deepEqual(request, {
      protocolVersion: 1,
      method: "hosts.load",
      params: {},
    });
    return { revision: 2 };
  };
  assert.deepEqual(await machkit.hosts("load"), { revision: 2 });
});

test("copy feedback waits for the native acknowledgement", async () => {
  events.length = 0;
  let acknowledge: ((value: BridgeResponse) => void) | undefined;
  postMessage = () =>
    new Promise((resolve) => {
      acknowledge = resolve;
    });
  const copy = machkit.copy("value");
  assert.equal(events.length, 0);
  assert.ok(acknowledge);
  acknowledge({ ok: true });
  assert.equal(await copy, true);
  assert.equal(events.at(-1)?.type, "machkit:copy-result");
  assert.equal(events.at(-1)?.detail?.ok, true);
});

test("readClipboard returns native pasteboard text", async () => {
  postMessage = async (request) => {
    assert.equal(request.method, "clipboard.read");
    assert.deepEqual(request.params, {});
    return { text: '{"a":1}' };
  };
  assert.equal(await machkit.readClipboard(), '{"a":1}');
});

test("bridge requests time out instead of hanging forever", async () => {
  postMessage = () => new Promise(() => {});
  await assert.rejects(
    machkit.request("hosts.load", {}, { timeout: 5 }),
    /timed out/,
  );
});

test("storage helpers round-trip through the native bridge", async () => {
  postMessage = async (request) => {
    assert.equal(request.method, "storage.set");
    assert.deepEqual(request.params, { key: "prefs", value: "{\"count\":10}" });
    return { ok: true };
  };
  assert.equal(await machkit.setItem("prefs", "{\"count\":10}"), true);

  postMessage = async (request) => {
    assert.equal(request.method, "storage.get");
    assert.deepEqual(request.params, { key: "prefs" });
    return { value: "{\"count\":10}" };
  };
  assert.equal(await machkit.getItem("prefs"), "{\"count\":10}");
});

test("appearance preferences apply light, dark, and system themes", () => {
  machkit.applyPreferences({ appearance: "dark" } satisfies Partial<MachKitPreferences>);
  assert.equal(document.documentElement.dataset.appearance, "dark");
  assert.equal(document.documentElement.style.colorScheme, "dark");

  machkit.applyPreferences({ appearance: "light" });
  assert.equal(document.documentElement.dataset.appearance, "light");
  assert.equal(document.documentElement.style.colorScheme, "light");

  machkit.applyPreferences({ appearance: "system" });
  assert.equal(document.documentElement.dataset.appearance, undefined);
  assert.equal(document.documentElement.style.colorScheme, "");
});
