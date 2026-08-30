import {
  formatJSON,
  minifyJSON,
  parseJSON,
  queryPath,
  sortKeysDeep,
  type ParseResult,
  type PathQueryResult,
} from "./json.js";

let cachedSource: string | null = null;
let cachedParsed: ParseResult | null = null;

export type JsonWorkerAnalyzeRequest = {
  id: string | number;
  type: "analyze";
  source?: string;
  path?: string;
};

export type JsonWorkerTransformRequest = {
  id: string | number;
  type: "transform";
  source?: string;
  operation?: "minify" | "sort" | "format" | string;
};

export type JsonWorkerRequest = JsonWorkerAnalyzeRequest | JsonWorkerTransformRequest;

export type JsonWorkerAnalyzeResponse = {
  id: string | number;
  type: "analyze";
  source?: string;
  path?: string;
  parsed: ParseResult;
  pathQuery: PathQueryResult;
};

export type JsonWorkerTransformResponse = {
  id: string | number;
  type: "transform";
  ok: boolean;
  source?: string;
  error?: string;
};

export type JsonWorkerResponse = JsonWorkerAnalyzeResponse | JsonWorkerTransformResponse;

self.onmessage = ({ data }: MessageEvent<JsonWorkerRequest>) => {
  const { id, type = "analyze", source } = data;
  const path = data.type === "analyze" ? data.path : undefined;
  try {
    if (source !== cachedSource) {
      cachedSource = source ?? null;
      // Keep the editor literal — do not unwrap escaped JSON string layers.
      cachedParsed = parseJSON(source, { unwrap: false });
    }
    if (!cachedParsed) throw new Error("Unable to analyze JSON");
    if (type === "transform") {
      if (!cachedParsed.ok) throw new Error(cachedParsed.error || "Invalid JSON");
      const operation = data.type === "transform" ? data.operation : undefined;
      const transformed = operation === "minify"
        ? minifyJSON(cachedParsed.data)
        : operation === "sort"
          ? formatJSON(sortKeysDeep(cachedParsed.data))
          : formatJSON(cachedParsed.data);
      const response: JsonWorkerTransformResponse = { id, type: "transform", ok: true, source: transformed };
      self.postMessage(response);
      return;
    }
    const pathQuery = cachedParsed.ok
      ? queryPath(cachedParsed.data, path)
      : { ok: true as const, error: null, matches: [] };
    const response: JsonWorkerAnalyzeResponse = {
      id,
      type: "analyze",
      source,
      path,
      parsed: cachedParsed,
      pathQuery,
    };
    self.postMessage(response);
  } catch (error) {
    if (type === "transform") {
      const response: JsonWorkerTransformResponse = {
        id,
        type: "transform",
        ok: false,
        error: error instanceof Error ? error.message : "Unable to transform JSON",
      };
      self.postMessage(response);
      return;
    }
    const response: JsonWorkerAnalyzeResponse = {
      id,
      type: "analyze",
      source,
      path,
      parsed: {
        ok: false,
        error: error instanceof Error ? error.message : "Unable to analyze JSON",
        data: null,
        unwrapped: false,
      },
      pathQuery: { ok: true, error: null, matches: [] },
    };
    self.postMessage(response);
  }
};
