import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues } from "../../src/i18n-catalog.js";
import { messages } from "./messages.js";
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
  hashMD5Variants,
} from "./codec.js";

test("catalog keys stay complete", () => {
  assert.deepEqual(catalogIssues(messages), []);
});

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

test("encodes Base16/36/58/85 and text encodings", async () => {
  const {
    encodeBase16,
    decodeBase16,
    encodeBase36,
    decodeBase36,
    encodeBase58,
    decodeBase58,
    encodeBase85,
    decodeBase85,
    encodeUTF8Bytes,
    decodeUTF8Bytes,
    encodeASCII,
    decodeASCII,
    encodeNative,
    decodeNative,
  } = await import("./codec.js");

  assert.equal(encodeBase16("Hi"), "4869");
  assert.equal(decodeBase16("48 69").value, "Hi");
  assert.equal(decodeBase36(encodeBase36("MachKit")).value, "MachKit");
  assert.equal(decodeBase58(encodeBase58("MachKit")).value, "MachKit");
  assert.equal(decodeBase85(encodeBase85("Hello")).value, "Hello");
  assert.equal(decodeBase85(encodeBase85("你好")).value, "你好");

  assert.equal(encodeUTF8Bytes("你好"), "E4 BD A0 E5 A5 BD");
  assert.equal(decodeUTF8Bytes("E4BDA0E5A5BD").value, "你好");
  assert.equal(encodeASCII("Hi中"), "72 105 20013");
  assert.equal(decodeASCII("72 105 20013").value, "Hi中");
  assert.equal(encodeNative("你好abc"), "\\u4f60\\u597dabc");
  assert.equal(decodeNative("\\u4f60\\u597dabc").value, "你好abc");

  assert.equal((await convertCodec({ tab: "base16", direction: "encode", input: "Hi" })).value, "4869");
  assert.equal((await convertCodec({ tab: "utf-8", direction: "encode", input: "你好" })).value, "E4 BD A0 E5 A5 BD");
  assert.equal((await convertCodec({ tab: "ascii", direction: "encode", input: "A" })).value, "65");
  assert.equal((await convertCodec({ tab: "native", direction: "encode", input: "中" })).value, "\\u4e2d");
});

test("hashes text with MD5 and SHA-256", async () => {
  assert.equal(await hashText("hello", "MD5"), "5d41402abc4b2a76b9719d911017c592");
  assert.equal(
    await hashText("hello", "SHA-256"),
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  );
});

test("builds MD5 32/16 lower and upper variants", async () => {
  const variants = await hashMD5Variants("hello");
  assert.deepEqual(variants, {
    lower32: "5d41402abc4b2a76b9719d911017c592",
    upper32: "5D41402ABC4B2A76B9719D911017C592",
    lower16: "5d41402abc4b2a76",
    upper16: "5D41402ABC4B2A76",
  });
});

test("computes HMAC-SHA-256 and HMAC-MD5", async () => {
  assert.equal(
    await hashText("hello", "HMAC-SHA-256", "key"),
    "9307b3b915efb5171ff14d8cb55fbcc798c6c0ef1456d66ded1a6aa723a58b7b",
  );
  assert.equal(await hashText("hello", "HMAC-MD5", "key"), "04130747afca4d79e32e87cf2104f087");
});

test("convertCodec routes tabs", async () => {
  const base64 = await convertCodec({ tab: "base64", direction: "encode", input: "hi" });
  assert.equal(base64.value, "aGk=");
  const hashed = await convertCodec({ tab: "hash", input: "hi", algorithm: "MD5" });
  assert.equal(hashed.value, "49f68a5c8493ec2c0bf489821c21fc3b");
  const html = await convertCodec({ tab: "html", direction: "encode", input: "<ok>" });
  assert.equal(html.value, "&lt;ok&gt;");
});

test("binary decimal punycode json qp rot13 data-uri gbk round trips", async () => {
  const binary = await convertCodec({ tab: "binary", direction: "encode", input: "Hi" });
  assert.equal(binary.value, "01001000 01101001");
  assert.equal(
    (await convertCodec({ tab: "binary", direction: "decode", input: binary.value })).value,
    "Hi",
  );

  const decimal = await convertCodec({ tab: "decimal", direction: "encode", input: "Hi" });
  assert.equal(decimal.value, "72 105");
  assert.equal(
    (await convertCodec({ tab: "decimal", direction: "decode", input: "72,105" })).value,
    "Hi",
  );

  const puny = await convertCodec({ tab: "punycode", direction: "encode", input: "中国.com" });
  assert.equal(puny.value, "xn--fiqs8s.com");
  assert.equal(
    (await convertCodec({ tab: "punycode", direction: "decode", input: puny.value })).value,
    "中国.com",
  );

  const json = await convertCodec({ tab: "json", direction: "encode", input: 'a"b\n' });
  assert.equal(json.value, 'a\\"b\\n');
  assert.equal(
    (await convertCodec({ tab: "json", direction: "decode", input: json.value })).value,
    'a"b\n',
  );

  const qp = await convertCodec({ tab: "quoted-printable", direction: "encode", input: "café" });
  assert.equal(qp.value.includes("=C3=A9"), true);
  assert.equal(
    (await convertCodec({ tab: "quoted-printable", direction: "decode", input: qp.value })).value,
    "café",
  );

  assert.equal((await convertCodec({ tab: "rot13", direction: "encode", input: "Hello" })).value, "Uryyb");
  assert.equal((await convertCodec({ tab: "rot13", direction: "decode", input: "Uryyb" })).value, "Hello");

  const dataURI = await convertCodec({ tab: "data-uri", direction: "encode", input: "hi" });
  assert.equal(dataURI.value, "data:text/plain;charset=utf-8;base64,aGk=");
  assert.equal(
    (await convertCodec({ tab: "data-uri", direction: "decode", input: dataURI.value })).value,
    "hi",
  );

  const radix = await convertCodec({ tab: "radix", input: "FF", fromRadix: 16, toRadix: 10 });
  assert.equal(radix.value, "255");
  assert.equal(
    (await convertCodec({ tab: "radix", input: "0b1010", fromRadix: 2, toRadix: 16 })).value,
    "A",
  );
  assert.equal(
    (await convertCodec({ tab: "radix", input: "255", fromRadix: 10, toRadix: 2 })).value,
    "11111111",
  );
  assert.equal((await convertCodec({ tab: "radix", input: "2", fromRadix: 2, toRadix: 10 })).ok, false);
  assert.equal((await convertCodec({ tab: "radix", input: "-10", fromRadix: 10, toRadix: 16 })).value, "-A");
  assert.equal((await convertCodec({ tab: "radix", input: "0xFF", fromRadix: 16, toRadix: 10 })).value, "255");
  assert.equal((await convertCodec({ tab: "radix", input: "0o17", fromRadix: 8, toRadix: 10 })).value, "15");
  assert.equal((await convertCodec({ tab: "radix", input: "ZZ", fromRadix: 36, toRadix: 10 })).value, "1295");
  assert.equal((await convertCodec({ tab: "radix", input: " 1_000 ", fromRadix: 10, toRadix: 16 })).value, "3E8");
  assert.equal((await convertCodec({ tab: "radix", input: "", fromRadix: 10, toRadix: 2 })).value, "");

  const { inspectDataURI, encodeDataURI } = await import("./codec.js");
  const pngURI =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
  const inspected = inspectDataURI(pngURI);
  assert.equal(inspected.ok, true);
  if (inspected.ok) {
    assert.equal(inspected.isImage, true);
    assert.equal(inspected.extension, "png");
    assert.equal(inspected.byteLength > 0, true);
  }
  assert.equal(
    (await convertCodec({ tab: "data-uri", direction: "decode", input: pngURI })).value,
    "",
  );

  const svgMarkup = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="1"/></svg>';
  const svgURI = encodeDataURI(svgMarkup, "image/svg+xml");
  const svgInspected = inspectDataURI(svgURI);
  assert.equal(svgInspected.ok, true);
  if (svgInspected.ok) {
    assert.equal(svgInspected.isImage, true);
    assert.equal(svgInspected.isText, true);
    assert.equal(svgInspected.extension, "svg");
    assert.equal(svgInspected.text, svgMarkup);
  }
  assert.equal(
    (await convertCodec({ tab: "data-uri", direction: "decode", input: svgURI })).value,
    svgMarkup,
  );

  const gbk = await convertCodec({ tab: "gbk", direction: "encode", input: "你好" });
  assert.equal(gbk.value, "c4e3bac3");
  assert.equal((await convertCodec({ tab: "gbk", direction: "decode", input: gbk.value })).value, "你好");
});
