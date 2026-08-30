export const maxURLInput = 8_000;

export type URLParts = {
  protocol: string;
  username: string;
  password: string;
  hostname: string;
  port: string;
  pathname: string;
  search: string;
  hash: string;
};

export type QueryItem = { key: string; value: string };

export type ParseURLResult =
  | { ok: true; error: null; href: string; parts: URLParts; query: QueryItem[] }
  | { ok: false; error: string; parts: URLParts; query: QueryItem[]; href?: undefined };

export type BuildURLResult = { ok: true; error: null; href: string } | { ok: false; error: string; href: string };

function emptyParts(): URLParts {
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

function queryFromSearchParams(params: URLSearchParams): QueryItem[] {
  const query: QueryItem[] = [];
  params.forEach((value, key) => {
    query.push({ key, value });
  });
  return query;
}

export function parseURL(input: unknown): ParseURLResult {
  const text = String(input ?? "").trim();
  if (!text) return { ok: false as const, error: "empty", parts: emptyParts(), query: [] };
  if (text.length > maxURLInput) return { ok: false as const, error: "too-large", parts: emptyParts(), query: [] };

  let url: URL;
  try {
    url = new URL(text);
  } catch {
    try {
      url = new URL(`https://${text}`);
    } catch {
      return { ok: false as const, error: "invalid", parts: emptyParts(), query: [] };
    }
  }

  return {
    ok: true as const,
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

function safeDecode(value: string): string {
  if (!value) return "";
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export function buildURL(parts: Partial<URLParts> | null | undefined, query: QueryItem[] = []): BuildURLResult {
  const protocol = String(parts?.protocol || "https").replace(/:$/, "") || "https";
  const hostname = String(parts?.hostname || "").trim();
  if (!hostname) return { ok: false as const, error: "missing-host", href: "" };

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
    return { ok: true as const, error: null, href: url.href };
  } catch {
    return { ok: false as const, error: "invalid", href: "" };
  }
}

export function encodeURIComponentSafe(input: unknown): string {
  return encodeURIComponent(String(input ?? ""));
}

export function decodeURIComponentSafe(
  input: unknown,
): { ok: true; text: string; error?: undefined } | { ok: false; text: string; error: string } {
  try {
    return { ok: true as const, text: decodeURIComponent(String(input ?? "").replace(/\+/g, " ")) };
  } catch {
    return { ok: false as const, text: "", error: "invalid" };
  }
}
