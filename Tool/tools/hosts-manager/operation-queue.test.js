import test from "node:test";
import assert from "node:assert/strict";
import { createOperationQueue } from "./operation-queue.js";

test("serializes operations even when an earlier operation fails", async () => {
  const events = [];
  const queue = createOperationQueue((pending) => events.push(`pending:${pending}`));
  let releaseFirst;
  const first = queue.run(async () => {
    events.push("first:start");
    await new Promise((resolve) => { releaseFirst = resolve; });
    events.push("first:end");
    throw new Error("expected");
  });
  const second = queue.run(async () => {
    events.push("second:start");
    return "saved";
  });

  await Promise.resolve();
  assert.deepEqual(events, ["pending:1", "first:start"]);
  releaseFirst();
  await assert.rejects(first, /expected/);
  assert.equal(await second, "saved");
  assert.deepEqual(events, [
    "pending:1", "first:start", "first:end", "pending:0",
    "pending:1", "second:start", "pending:0",
  ]);
});
