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
  __SIFT__: { locale: "en", appearance: "system" },
  webkit: { messageHandlers: { bridge: { postMessage: (request) => postMessage(request) } } },
  setTimeout,
  clearTimeout,
  dispatchEvent: (event) => events.push(event),
};
Object.defineProperty(globalThis, "navigator", {
  configurable: true,
  value: { language: "en" },
});

const { sift } = await import("./sift.js");

test("native requests carry a versioned method contract", async () => {
  postMessage = async (request) => {
    assert.deepEqual(request, {
      protocolVersion: 1,
      method: "hosts.load",
      params: {},
    });
    return { revision: 2 };
  };
  assert.deepEqual(await sift.hosts("load"), { revision: 2 });
});

test("copy feedback waits for the native acknowledgement", async () => {
  events.length = 0;
  let acknowledge;
  postMessage = () => new Promise((resolve) => { acknowledge = resolve; });
  const copy = sift.copy("value");
  assert.equal(events.length, 0);
  acknowledge({ ok: true });
  assert.equal(await copy, true);
  assert.equal(events.at(-1).type, "sift:copy-result");
  assert.equal(events.at(-1).detail.ok, true);
});

test("bridge requests time out instead of hanging forever", async () => {
  postMessage = () => new Promise(() => {});
  await assert.rejects(
    sift.request("hosts.load", {}, { timeout: 5 }),
    /timed out/,
  );
});
