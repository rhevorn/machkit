export const maxURLInput = 8_000;

function emptyParts() {
  return {
    protocol: "https",
    username: "",
    password: "",
    hostname: "",
    port: "",
    pathname: "",
    search: "",
    hash: "",
  };
}

function queryFromSearchParams(params) {
  const query = [];
  params.forEach((value, key) => {
    query.push({ key, value });
  });
  return query;
}

export function parseURL(input) {
  const text = String(input ?? "").trim();
  if (!text) return { ok: false, error: "empty", parts: emptyParts(), query: [] };
  if (text.length > maxURLInput) return { ok: false, error: "too-large", parts: emptyParts(), query: [] };

  let url;
  try {
    url = new URL(text);
  } catch {
    try {
      url = new URL(`https://${text}`);
    } catch {
      return { ok: false, error: "invalid", parts: emptyParts(), query: [] };
    }
  }

  return {
    ok: true,
    error: null,
    href: url.href,
    parts: {
      protocol: url.protocol.replace(/:$/, ""),
      username: safeDecode(url.username),
      password: safeDecode(url.password),
      hostname: url.hostname,
      port: url.port,
      pathname: url.pathname || "",
      search: url.search.startsWith("?") ? url.search.slice(1) : url.search,
      hash: url.hash.startsWith("#") ? url.hash.slice(1) : url.hash,
    },
    query: queryFromSearchParams(url.searchParams),
  };
}

function safeDecode(value) {
  if (!value) return "";
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export function buildURL(parts, query = []) {
  const protocol = String(parts?.protocol || "https").replace(/:$/, "") || "https";
  const hostname = String(parts?.hostname || "").trim();
  if (!hostname) return { ok: false, error: "missing-host", href: "" };

  try {
    const url = new URL(`${protocol}://${hostname}`);
    if (parts?.username) url.username = parts.username;
    if (parts?.password) url.password = parts.password;
    if (parts?.port) url.port = String(parts.port);
    url.pathname = parts?.pathname || "";
    url.hash = parts?.hash ? String(parts.hash).replace(/^#/, "") : "";
    url.search = "";
    for (const item of query) {
      const key = String(item?.key ?? "");
      if (!key) continue;
      url.searchParams.append(key, String(item?.value ?? ""));
    }
    return { ok: true, error: null, href: url.href };
  } catch {
    return { ok: false, error: "invalid", href: "" };
  }
}

export function encodeURIComponentSafe(input) {
  return encodeURIComponent(String(input ?? ""));
}

export function decodeURIComponentSafe(input) {
  try {
    return { ok: true, text: decodeURIComponent(String(input ?? "").replace(/\+/g, " ")) };
  } catch {
    return { ok: false, text: "", error: "invalid" };
  }
}
