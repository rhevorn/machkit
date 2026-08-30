const FIELD_NAMES = ["minute", "hour", "dayOfMonth", "month", "dayOfWeek"];

function parseList(field: string, min: number, max: number) {
  const values = new Set<number>();
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
  return [...values].sort((left: number, right: number) => left - right);
}

export function parseCron(expression: unknown) {
  const text = String(expression ?? "").trim().replace(/\s+/g, " ");
  if (!text) {
    return { ok: false as const, error: "empty", fields: null, dayOfMonthAny: false, dayOfWeekAny: false };
  }
  const parts = text.split(" ");
  if (parts.length !== 5) {
    return { ok: false as const, error: "field-count", fields: null, dayOfMonthAny: false, dayOfWeekAny: false };
  }

  const ranges = [
    [0, 59],
    [0, 23],
    [1, 31],
    [1, 12],
    [0, 7], // 0–6 plus 7 as Sunday synonym
  ];
  const fields: Record<string, number[]> = {};
  for (let index = 0; index < 5; index += 1) {
    const values = parseList(parts[index], ranges[index][0], ranges[index][1]);
    if (!values) {
      return {
        ok: false as const,
        error: "invalid-field",
        fields: null,
        dayOfMonthAny: false,
        dayOfWeekAny: false,
      };
    }
    if (FIELD_NAMES[index] === "dayOfWeek") {
      fields.dayOfWeek = [...new Set(values.map((value) => (value === 7 ? 0 : value)))].sort(
        (left: number, right: number) => left - right,
      );
    } else {
      fields[FIELD_NAMES[index]] = values;
    }
  }
  // Vixie: literal `*` means unrestricted; both-restricted day fields use OR.
  return {
    ok: true as const,
    error: null,
    expression: text,
    fields,
    dayOfMonthAny: parts[2] === "*",
    dayOfWeekAny: parts[4] === "*",
  };
}

function matchesDate(
  fields: Record<string, number[]>,
  date: Date,
  dayOfMonthAny: boolean,
  dayOfWeekAny: boolean,
) {
  if (
    !fields.minute.includes(date.getMinutes())
    || !fields.hour.includes(date.getHours())
    || !fields.month.includes(date.getMonth() + 1)
  ) {
    return false;
  }

  const domMatch = fields.dayOfMonth.includes(date.getDate());
  const dowMatch = fields.dayOfWeek.includes(date.getDay());
  if (dayOfMonthAny || dayOfWeekAny) {
    return (dayOfMonthAny || domMatch) && (dayOfWeekAny || dowMatch);
  }
  // Both day-of-month and day-of-week restricted → OR (Vixie crontab).
  return domMatch || dowMatch;
}

export function nextCronRuns(expression: unknown, { count = 5, from = new Date() }: { count?: number; from?: Date } = {}) {
  const parsed = parseCron(expression);
  if (!parsed.ok) return { ...parsed, runs: [] };

  const runs: Date[] = [];
  const cursor = new Date(from.getTime());
  cursor.setSeconds(0, 0);
  cursor.setMinutes(cursor.getMinutes() + 1);

  // Cap search far enough for sparse schedules (e.g. monthly × 100).
  const searchMinutes = Math.max(60 * 24 * 370 * 2, count * 60 * 24 * 40);
  for (let guard = 0; guard < searchMinutes && runs.length < count; guard += 1) {
    if (matchesDate(parsed.fields!, cursor, parsed.dayOfMonthAny, parsed.dayOfWeekAny)) {
      runs.push(new Date(cursor.getTime()));
    }
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
