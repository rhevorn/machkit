import { formatJSON, minifyJSON, parseJSON, queryPath, sortKeysDeep } from "./json.js";

let cachedSource = null;
let cachedParsed = null;

self.onmessage = ({ data }) => {
  const { id, type = "analyze", source, path } = data;
  try {
    if (source !== cachedSource) {
      cachedSource = source;
      // Keep the editor literal — do not unwrap escaped JSON string layers.
      cachedParsed = parseJSON(source, { unwrap: false });
    }
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
      : { ok: true, error: null, matches: [] };
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
