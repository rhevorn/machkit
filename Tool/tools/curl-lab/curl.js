export const maxCurlInput = 100_000;
export const httpMethods = Object.freeze(["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]);
export const bodyModes = Object.freeze(["none", "raw", "urlencoded", "formdata"]);

let seq = 0;
function nid(prefix = "n") {
  seq += 1;
  return `${prefix}_${seq}_${Math.random().toString(36).slice(2, 7)}`;
}

export function createPair(key = "", value = "") {
  return { id: nid("p"), key, value };
}

export function createFormField(key = "", value = "", kind = "text") {
  return {
    id: nid("f"),
    key,
    value,
    kind: kind === "file" ? "file" : "text",
  };
}

export function createEmptyRequest() {
  return {
    method: "GET",
    url: "https://httpbin.org/get",
    headers: [createPair("Accept", "application/json")],
    query: [],
    bodyMode: "none",
    body: "",
    formFields: [],
    insecure: false,
    followRedirects: true,
    compressed: false,
  };
}

function shellQuote(value) {
  const text = String(value ?? "");
  if (!text) return "''";
  if (/^[A-Za-z0-9_./:?&=%+,@~-]+$/.test(text)) return text;
  return `'${text.replace(/'/g, `'\\''`)}'`;
}

function tokenize(input) {
  const tokens = [];
  let i = 0;
  const s = String(input ?? "").trim();
  while (i < s.length) {
    if (/\s/.test(s[i])) {
      i += 1;
      continue;
    }
    if (s[i] === "'" || s[i] === '"') {
      const quote = s[i];
      i += 1;
      let value = "";
      while (i < s.length && s[i] !== quote) {
        if (quote === '"' && s[i] === "\\" && i + 1 < s.length) {
          value += s[i + 1];
          i += 2;
          continue;
        }
        value += s[i];
        i += 1;
      }
      i += 1;
      tokens.push(value);
      continue;
    }
    let value = "";
    while (i < s.length && !/\s/.test(s[i])) {
      value += s[i];
      i += 1;
    }
    tokens.push(value);
  }
  return tokens;
}

function parseHeaderLine(line) {
  const idx = String(line).indexOf(":");
  if (idx === -1) return createPair(String(line).trim(), "");
  return createPair(line.slice(0, idx).trim(), line.slice(idx + 1).trim());
}

function splitUrlQuery(url) {
  try {
    const parsed = new URL(url);
    const query = [];
    parsed.searchParams.forEach((value, key) => {
      query.push(createPair(key, value));
    });
    parsed.search = "";
    return { url: parsed.toString(), query };
  } catch {
    const q = url.indexOf("?");
    if (q === -1) return { url, query: [] };
    const base = url.slice(0, q);
    const query = [];
    for (const part of url.slice(q + 1).split("&")) {
      if (!part) continue;
      const eq = part.indexOf("=");
      if (eq === -1) query.push(createPair(decodeURIComponent(part), ""));
      else {
        query.push(
          createPair(
            decodeURIComponent(part.slice(0, eq)),
            decodeURIComponent(part.slice(eq + 1)),
          ),
        );
      }
    }
    return { url: base, query };
  }
}

function applyQuery(url, query) {
  const pairs = (query || []).filter((item) => String(item.key || "").trim());
  if (!pairs.length) return url;
  try {
    const parsed = new URL(url);
    parsed.search = "";
    for (const item of pairs) parsed.searchParams.append(item.key, item.value ?? "");
    return parsed.toString();
  } catch {
    const qs = pairs
      .map((item) => `${encodeURIComponent(item.key)}=${encodeURIComponent(item.value ?? "")}`)
      .join("&");
    return `${url}${url.includes("?") ? "&" : "?"}${qs}`;
  }
}

function headerMap(headers) {
  const map = new Map();
  for (const header of headers || []) {
    const key = String(header.key || "").trim();
    if (!key) continue;
    map.set(key.toLowerCase(), { key, value: header.value ?? "" });
  }
  return map;
}

function hasHeader(headers, name) {
  return headerMap(headers).has(String(name).toLowerCase());
}

function parseFormFieldToken(token, { forceText = false } = {}) {
  const text = String(token ?? "");
  const eq = text.indexOf("=");
  if (eq === -1) return createFormField(text, "", "text");
  const key = text.slice(0, eq);
  let value = text.slice(eq + 1);
  let kind = "text";
  if (!forceText && value.startsWith("@")) {
    kind = "file";
    value = value.slice(1);
  }
  return createFormField(key, value, kind);
}

function looksUrlEncoded(text) {
  const raw = String(text ?? "").trim();
  if (!raw || raw.startsWith("{") || raw.startsWith("[")) return false;
  if (!raw.includes("=")) return false;
  return /^[^=&\s]+=/.test(raw) || raw.includes("&");
}

function parseUrlEncodedBody(text) {
  const fields = [];
  for (const part of String(text ?? "").split("&")) {
    if (!part) continue;
    const eq = part.indexOf("=");
    if (eq === -1) {
      fields.push(createFormField(decodeURIComponent(part.replace(/\+/g, " ")), "", "text"));
    } else {
      fields.push(
        createFormField(
          decodeURIComponent(part.slice(0, eq).replace(/\+/g, " ")),
          decodeURIComponent(part.slice(eq + 1).replace(/\+/g, " ")),
          "text",
        ),
      );
    }
  }
  return fields;
}

export function buildCurl(request) {
  const method = httpMethods.includes(request?.method) ? request.method : "GET";
  const bodyMode = bodyModes.includes(request?.bodyMode) ? request.bodyMode : "none";
  const url = applyQuery(String(request?.url || "").trim() || "https://example.com/", request?.query || []);
  const parts = ["curl"];

  if (method !== "GET") parts.push("-X", method);
  parts.push(shellQuote(url));

  if (request?.followRedirects) parts.push("-L");
  if (request?.insecure) parts.push("-k");
  if (request?.compressed) parts.push("--compressed");

  for (const header of request?.headers || []) {
    const key = String(header.key || "").trim();
    if (!key) continue;
    if (bodyMode === "formdata" && key.toLowerCase() === "content-type") continue;
    parts.push("-H", shellQuote(`${key}: ${header.value ?? ""}`));
  }

  if (bodyMode === "urlencoded" && !hasHeader(request?.headers, "Content-Type")) {
    parts.push("-H", shellQuote("Content-Type: application/x-www-form-urlencoded"));
  }

  const fields = (request?.formFields || []).filter((field) => String(field.key || "").trim());

  if (bodyMode === "urlencoded" && fields.length) {
    if (method === "GET") parts.push("-G");
    for (const field of fields) {
      parts.push("--data-urlencode", shellQuote(`${field.key}=${field.value ?? ""}`));
    }
  } else if (bodyMode === "formdata" && fields.length) {
    for (const field of fields) {
      const value =
        field.kind === "file"
          ? `@${String(field.value || "").replace(/^@/, "")}`
          : String(field.value ?? "");
      parts.push("-F", shellQuote(`${field.key}=${value}`));
    }
  } else if (bodyMode === "raw") {
    const body = String(request?.body ?? "");
    if (body && method !== "GET" && method !== "HEAD") {
      parts.push("--data-raw", shellQuote(body));
    }
  }

  return parts.join(" ");
}

export function parseCurl(input) {
  const raw = String(input ?? "").trim();
  if (!raw) return { ok: false, error: "empty", request: null };
  if (raw.length > maxCurlInput) return { ok: false, error: "too-large", request: null };

  let text = raw.replace(/\\\r?\n/g, " ").trim();
  if (!/^curl\b/i.test(text)) {
    if (/^https?:\/\//i.test(text)) {
      const split = splitUrlQuery(text);
      return {
        ok: true,
        error: null,
        request: {
          ...createEmptyRequest(),
          url: split.url,
          query: split.query,
          headers: [],
        },
      };
    }
    return { ok: false, error: "not-curl", request: null };
  }

  const tokens = tokenize(text);
  if (!tokens.length || !/^curl$/i.test(tokens[0])) return { ok: false, error: "not-curl", request: null };

  const request = {
    ...createEmptyRequest(),
    headers: [],
    query: [],
    bodyMode: "none",
    body: "",
    formFields: [],
    followRedirects: false,
    insecure: false,
    compressed: false,
  };

  let url = "";
  let methodSet = false;
  let useGet = false;
  const dataParts = [];
  const urlEncodeParts = [];
  const formParts = [];

  for (let i = 1; i < tokens.length; i += 1) {
    const token = tokens[i];
    const next = () => tokens[++i];

    if (token === "-X" || token === "--request") {
      const value = (next() || "GET").toUpperCase();
      request.method = httpMethods.includes(value) ? value : "GET";
      methodSet = true;
      continue;
    }
    if (token === "-H" || token === "--header") {
      request.headers.push(parseHeaderLine(next() || ""));
      continue;
    }
    if (token === "-F" || token === "--form") {
      formParts.push(parseFormFieldToken(next() || ""));
      if (!methodSet) request.method = "POST";
      continue;
    }
    if (token === "--form-string") {
      formParts.push(parseFormFieldToken(next() || "", { forceText: true }));
      if (!methodSet) request.method = "POST";
      continue;
    }
    if (token === "--data-urlencode") {
      urlEncodeParts.push(parseFormFieldToken(next() || "", { forceText: true }));
      if (!methodSet) request.method = "POST";
      continue;
    }
    if (
      token === "-d" ||
      token === "--data" ||
      token === "--data-raw" ||
      token === "--data-binary" ||
      token === "--data-ascii"
    ) {
      dataParts.push(next() || "");
      if (!methodSet) request.method = "POST";
      continue;
    }
    if (token === "-u" || token === "--user") {
      request.headers.push(createPair("Authorization", `Basic ${next() || ""}`));
      continue;
    }
    if (token === "-A" || token === "--user-agent") {
      request.headers.push(createPair("User-Agent", next() || ""));
      continue;
    }
    if (token === "-b" || token === "--cookie") {
      request.headers.push(createPair("Cookie", next() || ""));
      continue;
    }
    if (token === "--url") {
      url = next() || "";
      continue;
    }
    if (token === "-k" || token === "--insecure") {
      request.insecure = true;
      continue;
    }
    if (token === "-L" || token === "--location") {
      request.followRedirects = true;
      continue;
    }
    if (token === "--compressed") {
      request.compressed = true;
      continue;
    }
    if (token === "-G" || token === "--get") {
      useGet = true;
      request.method = "GET";
      methodSet = true;
      continue;
    }
    if (token.startsWith("-")) continue;
    if (!url) url = token;
  }

  if (!url) return { ok: false, error: "missing-url", request: null };
  const split = splitUrlQuery(url);
  request.url = split.url;
  request.query = split.query;

  if (formParts.length) {
    request.bodyMode = "formdata";
    request.formFields = formParts;
  } else if (urlEncodeParts.length) {
    request.bodyMode = "urlencoded";
    request.formFields = urlEncodeParts;
    if (useGet) request.method = "GET";
  } else if (dataParts.length) {
    const joined = dataParts.join("&");
    const contentType = headerMap(request.headers).get("content-type")?.value || "";
    if (/application\/x-www-form-urlencoded/i.test(contentType) || looksUrlEncoded(joined)) {
      request.bodyMode = "urlencoded";
      request.formFields = parseUrlEncodedBody(joined);
      if (useGet) request.method = "GET";
    } else {
      request.bodyMode = "raw";
      request.body = dataParts.length === 1 ? dataParts[0] : joined;
    }
  }

  if (!request.headers.length) request.headers.push(createPair());
  if (
    (request.bodyMode === "urlencoded" || request.bodyMode === "formdata") &&
    !request.formFields.length
  ) {
    request.formFields.push(createFormField());
  }

  return { ok: true, error: null, request };
}

export function buildFetch(request) {
  const method = httpMethods.includes(request?.method) ? request.method : "GET";
  const bodyMode = bodyModes.includes(request?.bodyMode) ? request.bodyMode : "none";
  const url = applyQuery(String(request?.url || "").trim() || "https://example.com/", request?.query || []);
  const headers = {};
  for (const header of request?.headers || []) {
    const key = String(header.key || "").trim();
    if (!key) continue;
    if (bodyMode === "formdata" && key.toLowerCase() === "content-type") continue;
    headers[key] = header.value ?? "";
  }

  const fields = (request?.formFields || []).filter((field) => String(field.key || "").trim());
  const lines = [];
  lines.push(`const url = ${JSON.stringify(url)};`);

  if (bodyMode === "urlencoded" && fields.length) {
    lines.push("const body = new URLSearchParams();");
    for (const field of fields) {
      lines.push(`body.append(${JSON.stringify(field.key)}, ${JSON.stringify(field.value ?? "")});`);
    }
    if (!headers["Content-Type"] && !headers["content-type"]) {
      headers["Content-Type"] = "application/x-www-form-urlencoded";
    }
    const init = { method, headers, body: "BODY" };
    const json = JSON.stringify(init, null, 2).replace('"BODY"', "body");
    lines.push(`const response = await fetch(url, ${json});`);
  } else if (bodyMode === "formdata" && fields.length) {
    lines.push("const body = new FormData();");
    for (const field of fields) {
      if (field.kind === "file") {
        lines.push(
          `// body.append(${JSON.stringify(field.key)}, fileInput.files[0]); // ${JSON.stringify(field.value || "path")}`,
        );
        lines.push(
          `body.append(${JSON.stringify(field.key)}, ${JSON.stringify(field.value || "file.bin")}); // replace with File/Blob`,
        );
      } else {
        lines.push(`body.append(${JSON.stringify(field.key)}, ${JSON.stringify(field.value ?? "")});`);
      }
    }
    const init = { method, headers, body: "BODY" };
    const json = JSON.stringify(init, null, 2).replace('"BODY"', "body");
    lines.push(`const response = await fetch(url, ${json});`);
  } else {
    const init = { method };
    if (Object.keys(headers).length) init.headers = headers;
    const body = String(request?.body ?? "");
    if (bodyMode === "raw" && body && method !== "GET" && method !== "HEAD") init.body = body;
    lines.push(`const response = await fetch(url, ${JSON.stringify(init, null, 2)});`);
  }

  return lines.join("\n");
}
