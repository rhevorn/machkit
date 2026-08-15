const FIELD_NAMES = ["minute", "hour", "dayOfMonth", "month", "dayOfWeek"];

function parseList(field, min, max) {
  const values = new Set();
  for (const part of field.split(",")) {
    const piece = part.trim();
    if (!piece) return null;
    const [rangePart, stepPart] = piece.split("/");
    const step = stepPart === undefined ? 1 : Number(stepPart);
    if (!Number.isInteger(step) || step < 1) return null;

    let start;
    let end;
    if (rangePart === "*") {
      start = min;
      end = max;
    } else if (rangePart.includes("-")) {
      const [a, b] = rangePart.split("-");
      start = Number(a);
      end = Number(b);
      if (!Number.isInteger(start) || !Number.isInteger(end) || start > end) return null;
    } else {
      start = Number(rangePart);
      end = start;
      if (!Number.isInteger(start)) return null;
    }
    if (start < min || end > max) return null;
    for (let value = start; value <= end; value += step) values.add(value);
  }
  return [...values].sort((left, right) => left - right);
}

export function parseCron(expression) {
  const text = String(expression ?? "").trim().replace(/\s+/g, " ");
  if (!text) return { ok: false, error: "empty", fields: null };
  const parts = text.split(" ");
  if (parts.length !== 5) return { ok: false, error: "field-count", fields: null };

  const ranges = [
    [0, 59],
    [0, 23],
    [1, 31],
    [1, 12],
    [0, 6],
  ];
  const fields = {};
  for (let index = 0; index < 5; index += 1) {
    const values = parseList(parts[index], ranges[index][0], ranges[index][1]);
    if (!values) return { ok: false, error: "invalid-field", fields: null };
    fields[FIELD_NAMES[index]] = values;
  }
  return { ok: true, error: null, expression: text, fields };
}

function matchesDate(fields, date) {
  return fields.minute.includes(date.getMinutes())
    && fields.hour.includes(date.getHours())
    && fields.dayOfMonth.includes(date.getDate())
    && fields.month.includes(date.getMonth() + 1)
    && fields.dayOfWeek.includes(date.getDay());
}

export function nextCronRuns(expression, { count = 5, from = new Date() } = {}) {
  const parsed = parseCron(expression);
  if (!parsed.ok) return { ...parsed, runs: [] };

  const runs = [];
  const cursor = new Date(from.getTime());
  cursor.setSeconds(0, 0);
  cursor.setMinutes(cursor.getMinutes() + 1);

  // Cap search to ~2 years of minutes.
  for (let guard = 0; guard < 60 * 24 * 370 * 2 && runs.length < count; guard += 1) {
    if (matchesDate(parsed.fields, cursor)) runs.push(new Date(cursor.getTime()));
    cursor.setMinutes(cursor.getMinutes() + 1);
  }

  return { ok: true, error: null, expression: parsed.expression, fields: parsed.fields, runs };
}

export const cronPresets = Object.freeze([
  { id: "everyMinute", expression: "* * * * *" },
  { id: "hourly", expression: "0 * * * *" },
  { id: "daily", expression: "0 9 * * *" },
  { id: "weekdays", expression: "0 9 * * 1-5" },
  { id: "weekly", expression: "0 9 * * 1" },
  { id: "monthly", expression: "0 9 1 * *" },
]);
