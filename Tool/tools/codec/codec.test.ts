import test from "node:test";
import assert from "node:assert/strict";
import {
  convertCodec,
  decodeBase32,
  decodeBase62,
  decodeBase64,
  decodeEscape,
  decodeHTML,
  decodeHex,
  decodeURL,
  decodeUnicode,
  encodeBase32,
  encodeBase62,
  encodeBase64,
  encodeBase64URL,
  encodeEscape,
  encodeHTML,
  encodeHex,
  encodeURL,
  encodeUnicode,
  hashText,
} from "./codec.js";

test("encodes and decodes Base64 and Base64URL", () => {
  assert.equal(encodeBase64("hello"), "aGVsbG8=");
  assert.equal(decodeBase64("aGVsbG8=").value, "hello");
  assert.equal(encodeBase64URL("你好"), "5L2g5aW9");
  assert.equal(decodeBase64("@@@").ok, false);
});

test("encodes and decodes URL components", () => {
  assert.equal(encodeURL("a b&c"), "a%20b%26c");
  assert.equal(decodeURL("a%20b%26c").value, "a b&c");
  assert.equal(decodeURL("%E0%A4%A").ok, false);
});

test("encodes and decodes hex", () => {
  assert.equal(encodeHex("Hi"), "4869");
  assert.equal(decodeHex("4869").value, "Hi");
  assert.equal(decodeHex("48G9").ok, false);
  assert.equal(decodeHex("ff").ok, false);
});

test("encodes and decodes Base62", () => {
  const encoded = encodeBase62("MachKit");
  assert.equal(decodeBase62(encoded).value, "MachKit");
  assert.equal(decodeBase62("$$$").ok, false);
  const withLeadingZero = "\0MachKit";
  assert.equal(decodeBase62(encodeBase62(withLeadingZero)).value, withLeadingZero);
});

test("encodes and decodes HTML entities", () => {
  assert.equal(encodeHTML(`<a href="x">A&B</a>`), "&lt;a href=&quot;x&quot;&gt;A&amp;B&lt;/a&gt;");
  assert.equal(decodeHTML("&lt;div&gt;&#39;hi&#39;&lt;/div&gt;").value, "<div>'hi'</div>");
});

test("encodes and decodes Unicode escapes", () => {
  assert.equal(encodeUnicode("Hi你"), "\\u0048\\u0069\\u4f60");
  assert.equal(decodeUnicode("\\u4e2d\\u6587").value, "中文");
  assert.equal(decodeUnicode("\\u{1f600}").value, "😀");
  assert.equal(decodeUnicode("\\uZZZZ").ok, false);
});

test("escapes and unescapes common string sequences", () => {
  assert.equal(encodeEscape('a\n"b\\c'), 'a\\n\\"b\\\\c');
  assert.equal(decodeEscape('a\\n\\"b\\\\c').value, 'a\n"b\\c');
  assert.equal(decodeEscape("\\t\\r\\0").value, "\t\r\0");
  assert.equal(decodeEscape("\\q").ok, false);
});

test("encodes and decodes Base32", () => {
  assert.equal(encodeBase32("hello"), "NBSWY3DP");
  assert.equal(decodeBase32("NBSWY3DP").value, "hello");
  assert.equal(encodeBase32("foobar"), "MZXW6YTBOI======");
  assert.equal(decodeBase32("MZXW6YTBOI======").value, "foobar");
  assert.equal(decodeBase32("****").ok, false);
});

test("hashes text with MD5 and SHA-256", async () => {
  assert.equal(await hashText("hello", "MD5"), "5d41402abc4b2a76b9719d911017c592");
  assert.equal(
    await hashText("hello", "SHA-256"),
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  );
});

test("convertCodec routes tabs", async () => {
  const base64 = await convertCodec({ tab: "base64", direction: "encode", input: "hi" });
  assert.equal(base64.value, "aGk=");
  const hashed = await convertCodec({ tab: "hash", input: "hi", algorithm: "MD5" });
  assert.equal(hashed.value, "49f68a5c8493ec2c0bf489821c21fc3b");
  const html = await convertCodec({ tab: "html", direction: "encode", input: "<ok>" });
  assert.equal(html.value, "&lt;ok&gt;");
});
