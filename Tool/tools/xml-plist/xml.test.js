import assert from "node:assert/strict";
import { test } from "node:test";
import { formatXML, minifyXML, plistToJSON } from "./xml.js";

test("formats and minifies XML", () => {
  const formatted = formatXML("<root><a>1</a><b/></root>");
  assert.equal(formatted.ok, true);
  assert.match(formatted.text, /<root>\n {2}<a>1<\/a>/);
  assert.equal(minifyXML(formatted.text).text, "<root><a>1</a><b/></root>");
});

test("parses plist XML into JSON", () => {
  const plist = `<?xml version="1.0"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key>
  <string>machkit</string>
  <key>enabled</key>
  <true/>
  <key>count</key>
  <integer>3</integer>
</dict>
</plist>`;
  const result = plistToJSON(plist);
  assert.equal(result.ok, true);
  assert.match(result.text, /"name": "machkit"/);
  assert.match(result.text, /"enabled": true/);
  assert.match(result.text, /"count": 3/);
});
