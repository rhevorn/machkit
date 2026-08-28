import test from "node:test";
import assert from "node:assert/strict";

const events = [];
let postMessage = () => Promise.resolve({ ok: true });

globalThis.CustomEvent = class CustomEvent {
  constructor(type, options = {}) {
    this.type = type;
    this.detail = options.detail;
  }
};
globalThis.window = {
  __MACHKIT__: { locale: "en", appearance: "system" },
  webkit: { messageHandlers: { bridge: { postMessage: (request) => postMessage(request) } } },
  setTimeout,
  clearTimeout,
  dispatchEvent: (event) => events.push(event),
};
globalThis.document = {
  documentElement: {
    dataset: {},
    style: {},
  },
};
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
  let acknowledge;
  postMessage = () => new Promise((resolve) => { acknowledge = resolve; });
  const copy = machkit.copy("value");
  assert.equal(events.length, 0);
  acknowledge({ ok: true });
  assert.equal(await copy, true);
  assert.equal(events.at(-1).type, "machkit:copy-result");
  assert.equal(events.at(-1).detail.ok, true);
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
  machkit.applyPreferences({ appearance: "dark" });
  assert.equal(document.documentElement.dataset.appearance, "dark");
  assert.equal(document.documentElement.style.colorScheme, "dark");

  machkit.applyPreferences({ appearance: "light" });
  assert.equal(document.documentElement.dataset.appearance, "light");
  assert.equal(document.documentElement.style.colorScheme, "light");

  machkit.applyPreferences({ appearance: "system" });
  assert.equal(document.documentElement.dataset.appearance, undefined);
  assert.equal(document.documentElement.style.colorScheme, "");
});
