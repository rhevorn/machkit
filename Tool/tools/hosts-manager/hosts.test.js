import assert from "node:assert/strict";
import { test } from "node:test";
import {
  clearDraftBackup,
  draftBackupDiffers,
  localizePresetEnvironmentName,
  readDraftBackup,
  shouldKeepLocalDrafts,
  writeDraftBackup,
} from "./hosts.js";

const labels = {
  development: "开发环境",
  testing: "测试环境",
  production: "生产环境",
};

test("localizes preset environment names by id suffix", () => {
  assert.equal(
    localizePresetEnvironmentName({ id: "aaaa-0001", name: "Development" }, labels),
    "开发环境",
  );
  assert.equal(
    localizePresetEnvironmentName({ id: "bbbb-0002", name: "Testing" }, labels),
    "测试环境",
  );
  assert.equal(
    localizePresetEnvironmentName({ id: "cccc-0003", name: "Production" }, labels),
    "生产环境",
  );
});

test("keeps custom and renamed environments as stored", () => {
  assert.equal(
    localizePresetEnvironmentName({ id: "aaaa-0001", name: "Local staging" }, labels),
    "Local staging",
  );
  assert.equal(
    localizePresetEnvironmentName({ id: "custom", name: "Staging" }, labels),
    "Staging",
  );
  assert.equal(localizePresetEnvironmentName(null, labels), "");
});

test("detects newer local edits after save", () => {
  assert.equal(shouldKeepLocalDrafts(2, 2), false);
  assert.equal(shouldKeepLocalDrafts(3, 2), true);
});

test("round-trips draft backups in storage", () => {
  const storage = new Map();
  const api = {
    setItem: (key, value) => storage.set(key, value),
    getItem: (key) => storage.get(key) ?? null,
    removeItem: (key) => storage.delete(key),
  };
  const draft = {
    environments: [{ id: "1", name: "Dev", content: "127.0.0.1 a.test" }],
    sharedContent: "127.0.0.1 shared.test",
    activeEnvironmentID: "1",
  };
  writeDraftBackup(api, draft);
  assert.deepEqual(readDraftBackup(api), draft);
  assert.equal(draftBackupDiffers(draft, { ...draft, sharedContent: "other" }), true);
  assert.equal(draftBackupDiffers(draft, draft), false);
  clearDraftBackup(api);
  assert.equal(readDraftBackup(api), null);
});

test("ignores empty environment backups", () => {
  const storage = new Map();
  const api = {
    setItem: (key, value) => storage.set(key, value),
    getItem: (key) => storage.get(key) ?? null,
    removeItem: (key) => storage.delete(key),
  };
  writeDraftBackup(api, { environments: [], sharedContent: "x", activeEnvironmentID: null });
  assert.equal(readDraftBackup(api), null);
  api.setItem("machkit.hosts-manager.draft", JSON.stringify({ environments: [], sharedContent: "" }));
  assert.equal(readDraftBackup(api), null);
});
