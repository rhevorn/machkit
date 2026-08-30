import { formatJSON, minifyJSON, parseJSON, queryPath, sortKeysDeep, type ParseResult } from "./json.js";

let cachedSource: string | null = null;
let cachedParsed: ParseResult | null = null;

type WorkerRequest = {
  id: unknown;
  type?: string;
  source?: string;
  path?: string;
  operation?: string;
};

self.onmessage = ({ data }: MessageEvent<WorkerRequest>) => {
  const { id, type = "analyze", source, path } = data;
  try {
    if (source !== cachedSource) {
      cachedSource = source ?? null;
      // Keep the editor literal — do not unwrap escaped JSON string layers.
      cachedParsed = parseJSON(source, { unwrap: false });
    }
    if (!cachedParsed) throw new Error("Unable to analyze JSON");
    if (type === "transform") {
      if (!cachedParsed.ok) throw new Error(cachedParsed.error || "Invalid JSON");
      const transformed = data.operation === "minify"
        ? minifyJSON(cachedParsed.data)
        : data.operation === "sort"
          ? formatJSON(sortKeysDeep(cachedParsed.data))
          : formatJSON(cachedParsed.data);
      self.postMessage({ id, type, ok: true, source: transformed });
      return;
    }
    const pathQuery = cachedParsed.ok
      ? queryPath(cachedParsed.data, path)
      : { ok: true as const, error: null, matches: [] };
    self.postMessage({ id, type, source, path, parsed: cachedParsed, pathQuery });
  } catch (error) {
    if (type === "transform") {
      self.postMessage({ id, type, ok: false, error: error instanceof Error ? error.message : "Unable to transform JSON" });
      return;
    }
    self.postMessage({
      id,
      type,
      source,
      path,
      parsed: { ok: false, error: error instanceof Error ? error.message : "Unable to analyze JSON", data: null, unwrapped: false },
      pathQuery: { ok: true, error: null, matches: [] },
    });
  }
};
