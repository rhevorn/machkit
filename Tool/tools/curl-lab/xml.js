const maxXMLInput = 1_000_000;

function minifyXML(input) {
  const text = String(input ?? "");
  if (!text.trim()) return { ok: false, error: "empty", text: "" };
  if (text.length > maxXMLInput) return { ok: false, error: "too-large", text: "" };

  return {
    ok: true,
    error: null,
    text: text
      .replace(/<!--[\s\S]*?-->/g, "")
      .replace(/>\s+</g, "><")
      .trim(),
  };
}

/** Pretty-print an XML response body without evaluating or loading external content. */
export function formatXML(input, indentSize = 2) {
  const minified = minifyXML(input);
  if (!minified.ok) return minified;

  const pad = " ".repeat(Math.max(1, indentSize));
  const tokens = minified.text.replace(/(>)(<)(\/*)/g, "$1\n$2$3").split("\n");
  let depth = 0;
  const lines = [];

  for (const raw of tokens) {
    const line = raw.trim();
    if (!line) continue;
    if (/^<\/\w/.test(line)) depth = Math.max(depth - 1, 0);
    lines.push(`${pad.repeat(depth)}${line}`);
    if (
      /^<\w[^>]*[^/]>$/.test(line) &&
      !/^<\?/.test(line) &&
      !/^<!/.test(line) &&
      !/^<.*<\/\w/.test(line)
    ) {
      depth += 1;
    }
  }

  return { ok: true, error: null, text: `${lines.join("\n")}\n` };
}
