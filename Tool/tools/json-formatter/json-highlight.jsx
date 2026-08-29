import React from "react";

const HIGHLIGHT_CHAR_BUDGET = 80_000;

function escapeJsonString(value) {
  return JSON.stringify(value).slice(1, -1);
}

function renderValue(value, depth) {
  if (value === null) {
    return <span className="json-token-null">null</span>;
  }

  switch (typeof value) {
    case "boolean":
      return <span className="json-token-bool">{String(value)}</span>;
    case "number":
      return <span className="json-token-number">{Number.isFinite(value) ? String(value) : "null"}</span>;
    case "string":
      return depth === 0
        ? <span className="json-token-string">{value}</span>
        : <span className="json-token-string">"{escapeJsonString(value)}"</span>;
    case "object":
      break;
    default:
      return <span className="json-token-string">{String(value)}</span>;
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      return <span className="json-token-punct">[]</span>;
    }

    return (
      <>
        <span className="json-token-punct">[</span>
        {"\n"}
        {value.map((item, index) => (
          <React.Fragment key={index}>
            {"  ".repeat(depth + 1)}
            {renderValue(item, depth + 1)}
            {index < value.length - 1 ? <span className="json-token-punct">,</span> : null}
            {"\n"}
          </React.Fragment>
        ))}
        {"  ".repeat(depth)}
        <span className="json-token-punct">]</span>
      </>
    );
  }

  const entries = Object.entries(value);
  if (entries.length === 0) {
    return <span className="json-token-punct">{"{}"}</span>;
  }

  return (
    <>
      <span className="json-token-punct">{"{"}</span>
      {"\n"}
      {entries.map(([key, child], index) => (
        <React.Fragment key={`${key}-${index}`}>
          {"  ".repeat(depth + 1)}
          <span className="json-token-key">"{escapeJsonString(key)}"</span>
          <span className="json-token-punct">: </span>
          {renderValue(child, depth + 1)}
          {index < entries.length - 1 ? <span className="json-token-punct">,</span> : null}
          {"\n"}
        </React.Fragment>
      ))}
      {"  ".repeat(depth)}
      <span className="json-token-punct">{"}"}</span>
    </>
  );
}

export function JsonHighlight({ value, className = "" }) {
  let plain = null;
  try {
    plain = typeof value === "string" ? value : JSON.stringify(value, null, 2);
  } catch {
    plain = String(value);
  }

  const usePlain = !plain || plain.length > HIGHLIGHT_CHAR_BUDGET;

  return (
    <pre className={`json-highlight h-full min-h-0 min-w-0 flex-1 overflow-auto font-mono text-[12px] leading-relaxed break-all whitespace-pre-wrap ${className}`.trim()}>
      {usePlain ? plain : renderValue(value, 0)}
    </pre>
  );
}
