import test from "node:test";
import assert from "node:assert/strict";
import { fallbackRelease, resolveReleaseDownload } from "./release.js";

test("resolves the MachKit release asset from the latest tag", () => {
  const download = resolveReleaseDownload({
    tag_name: "v1.2.1",
    assets: [{
      name: "MachKit-1.2.1-macOS.zip",
      browser_download_url: "https://github.com/rhevorn/machkit/releases/download/v1.2.1/MachKit-1.2.1-macOS.zip",
    }],
  });

  assert.equal(download.tag, "v1.2.1");
  assert.equal(download.version, "1.2.1");
  assert.equal(download.downloadURL, "https://github.com/rhevorn/machkit/releases/download/v1.2.1/MachKit-1.2.1-macOS.zip");
});

test("constructs the MachKit asset URL from a tag when assets are omitted", () => {
  const download = resolveReleaseDownload({ tag_name: "v2.1.0" });
  assert.equal(
    download.downloadURL,
    "https://github.com/rhevorn/machkit/releases/download/v2.1.0/MachKit-2.1.0-macOS.zip",
  );
});

test("ignores assets that do not use the MachKit package name", () => {
  const download = resolveReleaseDownload({
    tag_name: "v2.1.0",
    assets: [{ name: "Other-2.1.0-macOS.zip", browser_download_url: "https://example.com/other.zip" }],
  });
  assert.equal(
    download.downloadURL,
    "https://github.com/rhevorn/machkit/releases/download/v2.1.0/MachKit-2.1.0-macOS.zip",
  );
});

test("uses the known direct download when release metadata is invalid", () => {
  assert.deepEqual(resolveReleaseDownload(null), fallbackRelease);
});
