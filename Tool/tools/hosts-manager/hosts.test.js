import assert from "node:assert/strict";
import { test } from "node:test";
import {
  localizePresetEnvironmentName,
  shouldKeepLocalDrafts,
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
