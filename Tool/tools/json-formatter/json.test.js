import test from "node:test";
import assert from "node:assert/strict";
import {
  byteSize,
  formatJSON,
  minifyJSON,
  parseJSON,
  pathAtOffset,
  queryPath,
  sortKeysDeep,
  stringifyValue,
  escapeJSONText,
  unescapeJSONText,
} from "./json.js";

const sample = {
  store: {
    book: [
      { category: "reference", author: "Nigel Rees", price: 8.95 },
      { category: "fiction", author: "Evelyn Waugh", price: 12.99 },
    ],
    bicycle: { color: "red", price: 19.95 },
  },
};

test("parses valid JSON and reports empty or invalid input", () => {
  assert.equal(parseJSON('{"a":1}').ok, true);
  assert.equal(parseJSON("").error, "empty");
  assert.equal(parseJSON("{").ok, false);
});

test("unwraps outer escaped JSON string layers", () => {
  const quoted = parseJSON('"{\\"a\\":1}"');
  assert.equal(quoted.ok, true);
  assert.equal(quoted.unwrapped, true);
  assert.deepEqual(quoted.data, { a: 1 });

  const body = parseJSON('{\\"a\\":1}');
  assert.equal(body.ok, true);
  assert.equal(body.unwrapped, true);
  assert.deepEqual(body.data, { a: 1 });

  const nested = parseJSON('"\\"{\\\\\\"a\\\\\\":1}\\""');
  assert.equal(nested.ok, true);
  assert.deepEqual(nested.data, { a: 1 });

  const plainString = parseJSON('"hello"');
  assert.equal(plainString.ok, true);
  assert.equal(plainString.unwrapped, false);
  assert.equal(plainString.data, "hello");

  const literal = parseJSON('"{\\"a\\":1}"', { unwrap: false });
  assert.equal(literal.ok, true);
  assert.equal(literal.unwrapped, false);
  assert.equal(literal.data, '{"a":1}');
});

test("formats, minifies, and sorts object keys", () => {
  const data = { b: 1, a: { d: 2, c: 3 } };
  assert.equal(minifyJSON(data), '{"b":1,"a":{"d":2,"c":3}}');
  assert.equal(formatJSON(sortKeysDeep(data), 2), '{\n  "a": {\n    "c": 3,\n    "d": 2\n  },\n  "b": 1\n}\n');

  let deeplyNested = { value: true };
  for (let depth = 0; depth < 10_000; depth += 1) deeplyNested = { child: deeplyNested };
  assert.doesNotThrow(() => sortKeysDeep(deeplyNested));
});

test("escapes and unescapes JSON text", () => {
  assert.equal(escapeJSONText('{"a":1}'), '"{\\"a\\":1}"');
  assert.equal(unescapeJSONText('"{\\"a\\":1}"'), '{"a":1}');
  assert.equal(unescapeJSONText('{\\"a\\":1}'), '{"a":1}');
  assert.equal(unescapeJSONText(escapeJSONText('{\n  "hello": "世界"\n}')), '{\n  "hello": "世界"\n}');
  assert.throws(() => unescapeJSONText(""), /empty/);
  assert.throws(() => unescapeJSONText('"unterminated'), /./);
});

test("queries dotted paths, indexes, wildcards, and recursive descent", () => {
  assert.deepEqual(
    queryPath(sample, "$.store.book[0].author").matches.map((match) => match.value),
    ["Nigel Rees"],
  );
  assert.deepEqual(
    queryPath(sample, "store.book[*].price").matches.map((match) => match.value),
    [8.95, 12.99],
  );
  assert.deepEqual(
    queryPath(sample, "$..author").matches.map((match) => match.value),
    ["Nigel Rees", "Evelyn Waugh"],
  );
  assert.deepEqual(
    queryPath(sample, "$.store['bicycle'].color").matches.map((match) => match.value),
    ["red"],
  );
  assert.equal(queryPath(sample, "$.store.book[9]").matches.length, 0);
  assert.equal(queryPath(sample, "$.store.book[").ok, false);

  let deeplyNested = { target: true };
  for (let depth = 0; depth < 10_000; depth += 1) deeplyNested = { child: deeplyNested };
  assert.equal(queryPath(deeplyNested, "$..target").matches.length, 1);
});

test("stringifies matched values for display and measures UTF-8 size", () => {
  assert.equal(stringifyValue("hello"), "hello");
  assert.equal(stringifyValue({ a: 1 }, 0), '{"a":1}');
  assert.equal(byteSize("你好"), 6);
});

test("resolves JSONPath at a document offset", () => {
  const source = '{\n  "store": {\n    "book": [\n      { "author": "Nigel" }\n    ]\n  }\n}\n';
  const author = source.indexOf('"Nigel"');
  assert.equal(pathAtOffset(source, author).path, "$.store.book[0].author");
  assert.equal(pathAtOffset(source, source.indexOf('"author"')).path, "$.store.book[0].author");
  assert.equal(pathAtOffset(source, source.indexOf('"book"')).path, "$.store.book");
  assert.equal(pathAtOffset(source, 0).path, "$");
  assert.equal(pathAtOffset("{", 0).ok, false);
});
