import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues, supportedLocales } from "./i18n-catalog.js";
import { messages as timestampMessages } from "../tools/timestamp-converter/messages.js";
import { messages as codecMessages } from "../tools/codec/messages.js";
import { messages as jsonMessages } from "../tools/json-formatter/messages.js";
import { messages as stringMessages } from "../tools/string-generator/messages.js";
import { labels as hostsMessages } from "../tools/hosts-manager/messages.js";
import { homeMessages } from "./home-messages.js";
import { runtimeMessages } from "./runtime/runtime-messages.js";
import { messages as certMessages } from "../tools/cert-lab/messages.js";
import { messages as chmodMessages } from "../tools/chmod-lab/messages.js";
import { messages as colorMessages } from "../tools/color-lab/messages.js";
import { messages as cronMessages } from "../tools/cron-expression/messages.js";
import { messages as curlMessages } from "../tools/curl-lab/messages.js";
import { messages as imageMessages } from "../tools/image-process/messages.js";
import { messages as ipMessages } from "../tools/ip-cidr/messages.js";
import { messages as jwtMessages } from "../tools/jwt-lab/messages.js";
import { messages as numberMessages } from "../tools/number-base/messages.js";
import { messages as portMessages } from "../tools/port-scan/messages.js";
import { messages as qrMessages } from "../tools/qr-code/messages.js";
import { messages as regexMessages } from "../tools/regex-lab/messages.js";
import { messages as diffMessages } from "../tools/text-diff/messages.js";
import { messages as urlMessages } from "../tools/url-lab/messages.js";

const localizedCatalogs = {
  timestamp: timestampMessages,
  codec: codecMessages,
  json: jsonMessages,
  string: stringMessages,
  hosts: hostsMessages,
  cert: certMessages,
  chmod: chmodMessages,
  color: colorMessages,
  cron: cronMessages,
  curl: curlMessages,
  image: imageMessages,
  ip: ipMessages,
  jwt: jwtMessages,
  number: numberMessages,
  port: portMessages,
  qr: qrMessages,
  regex: regexMessages,
  diff: diffMessages,
  url: urlMessages,
  home: homeMessages,
  runtime: runtimeMessages,
};

for (const [name, catalog] of Object.entries(localizedCatalogs)) {
  test(`${name} translations have the same non-empty keys`, () => {
    assert.deepEqual(catalogIssues(catalog), []);
  });
}

test("fully localized tools cover every supported locale", () => {
  for (const catalog of Object.values(localizedCatalogs)) {
    assert.deepEqual(Object.keys(catalog).sort(), [...supportedLocales].sort());
  }
});
