import assert from "node:assert/strict";
import { test } from "node:test";
import {
  clampQuality,
  formatBytes,
  outputFileName,
  parseTargetSize,
  ratioLabel,
  resolveDimensions,
  resolveOutputFormat,
  toPixels,
  validateBatch,
} from "./image.js";

test("clamps quality", () => {
  assert.equal(clampQuality(1.5), 1);
  assert.equal(clampQuality(0), 0.05);
});

test("converts dimension units to pixels", () => {
  assert.equal(toPixels(100, "px"), 100);
  assert.equal(toPixels(50, "%", 800), 400);
  assert.equal(toPixels(1, "in", 0, 96), 96);
  assert.equal(toPixels(2.54, "cm", 0, 96), 96);
  assert.equal(toPixels(25.4, "mm", 0, 96), 96);
});

test("resolves dimensions by max edge, width, and box", () => {
  assert.deepEqual(resolveDimensions(4000, 2000, { maxEdge: 1000 }), {
    width: 1000,
    height: 500,
    scaled: true,
  });
  assert.deepEqual(resolveDimensions(800, 600, { width: 400, unit: "px", lockAspect: true }), {
    width: 400,
    height: 300,
    scaled: true,
  });
  assert.deepEqual(resolveDimensions(800, 600, { width: 50, unit: "%", lockAspect: true }), {
    width: 400,
    height: 300,
    scaled: true,
  });
  assert.deepEqual(resolveDimensions(800, 600, { width: 400, height: 400, lockAspect: true }), {
    width: 400,
    height: 300,
    scaled: true,
  });
  assert.deepEqual(resolveDimensions(800, 600, { width: 400, height: 400, lockAspect: false }), {
    width: 400,
    height: 400,
    scaled: true,
  });
});

test("parses target size", () => {
  assert.equal(parseTargetSize(200, "KB").bytes, 200 * 1024);
  assert.equal(parseTargetSize(1.5, "MB").bytes, Math.round(1.5 * 1024 * 1024));
  assert.equal(parseTargetSize(0, "KB").error, "invalid-target");
});

test("resolves output names and formats", () => {
  assert.equal(resolveOutputFormat("png", "keep"), "png");
  assert.equal(outputFileName("Photo.PNG", "jpeg"), "Photo.jpg");
  assert.equal(formatBytes(1536), "1.5 KB");
  assert.equal(ratioLabel(1000, 700), "−30%");
});

test("validates batch limits", () => {
  assert.equal(validateBatch([]).error, "empty");
  assert.equal(validateBatch(Array.from({ length: 51 }, () => ({}))).error, "too-many");
  assert.equal(validateBatch([{}]).ok, true);
});
