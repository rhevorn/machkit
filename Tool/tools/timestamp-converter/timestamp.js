export const units = Object.freeze({
  nanoseconds: { perMillisecond: 1_000_000n },
  milliseconds: { perMillisecond: 1n },
  seconds: { perMillisecond: null },
});

export function timestampFromMilliseconds(milliseconds, unit) {
  const value = BigInt(Math.trunc(milliseconds));
  if (unit === "seconds") return (value / 1_000n).toString();
  return (value * units[unit].perMillisecond).toString();
}

export function millisecondsFromTimestamp(rawValue, unit) {
  const value = rawValue.trim();
  if (!/^-?\d+$/.test(value)) return null;

  try {
    const integer = BigInt(value);
    let milliseconds;
    if (unit === "seconds") milliseconds = integer * 1_000n;
    else milliseconds = integer / units[unit].perMillisecond;
    const result = Number(milliseconds);
    if (!Number.isSafeInteger(result) || Math.abs(result) > 8_640_000_000_000_000) return null;
    return result;
  } catch {
    return null;
  }
}

function partsAt(milliseconds, timeZone) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  return Object.fromEntries(
    formatter.formatToParts(new Date(milliseconds)).filter((part) => part.type !== "literal").map((part) => [part.type, Number(part.value)]),
  );
}

export function localDateTimeValue(milliseconds, timeZone) {
  const parts = partsAt(milliseconds, timeZone);
  const pad = (value) => String(value).padStart(2, "0");
  return `${parts.year}-${pad(parts.month)}-${pad(parts.day)}T${pad(parts.hour)}:${pad(parts.minute)}:${pad(parts.second)}`;
}

export function millisecondsFromLocalDateTime(value, timeZone) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/.exec(value);
  if (!match) return null;
  const [, year, month, day, hour, minute, second] = match.map(Number);
  const intendedUTC = Date.UTC(year, month - 1, day, hour, minute, second, 0);
  let candidate = intendedUTC;

  for (let iteration = 0; iteration < 3; iteration += 1) {
    const parts = partsAt(candidate, timeZone);
    const representedUTC = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second, 0);
    candidate -= representedUTC - intendedUTC;
  }

  return localDateTimeValue(candidate, timeZone) === value ? candidate : null;
}

export function formatDate(milliseconds, timeZone, locale) {
  return new Intl.DateTimeFormat(locale, {
    timeZone,
    dateStyle: "medium",
    timeStyle: "medium",
  }).format(new Date(milliseconds));
}

/** Locale-friendly long date/time, e.g. Friday, August 28, 2026 at 17:31:00. */
export function formatReadableDate(milliseconds, timeZone, locale) {
  return new Intl.DateTimeFormat(locale, {
    timeZone,
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).format(new Date(milliseconds));
}

/** Wall-clock time in zone as `yyyy-MM-dd HH:mm:ss`. */
export function formatLocalDateTime(milliseconds, timeZone) {
  return localDateTimeValue(milliseconds, timeZone).replace("T", " ");
}

function offsetMinutesAt(milliseconds, timeZone) {
  const parts = partsAt(milliseconds, timeZone);
  const representedUTC = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  return Math.round((representedUTC - Math.trunc(milliseconds / 1_000) * 1_000) / 60_000);
}

function numericOffset(minutes, separator = ":") {
  if (minutes === 0 && separator === ":") return "Z";
  const sign = minutes < 0 ? "-" : "+";
  const absolute = Math.abs(minutes);
  const hours = String(Math.floor(absolute / 60)).padStart(2, "0");
  const remainder = String(absolute % 60).padStart(2, "0");
  return `${sign}${hours}${separator}${remainder}`;
}

export function formatISO8601(milliseconds) {
  return new Date(milliseconds).toISOString();
}

export function formatRFC3339(milliseconds, timeZone) {
  return `${localDateTimeValue(milliseconds, timeZone)}${numericOffset(offsetMinutesAt(milliseconds, timeZone))}`;
}

export function formatRFC2822(milliseconds, timeZone) {
  const parts = partsAt(milliseconds, timeZone);
  const weekday = new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short" }).format(new Date(milliseconds));
  const month = new Intl.DateTimeFormat("en-US", { timeZone, month: "short" }).format(new Date(milliseconds));
  const pad = (value) => String(value).padStart(2, "0");
  const offset = numericOffset(offsetMinutesAt(milliseconds, timeZone), "");
  return `${weekday}, ${pad(parts.day)} ${month} ${parts.year} ${pad(parts.hour)}:${pad(parts.minute)}:${pad(parts.second)} ${offset}`;
}

export function timeZoneLabel(timeZone, locale, milliseconds = Date.now()) {
  const offsetName = new Intl.DateTimeFormat(locale, {
    timeZone,
    timeZoneName: "longOffset",
  }).formatToParts(new Date(milliseconds)).find((part) => part.type === "timeZoneName")?.value || "UTC";
  const normalizedOffset = offsetName.replace("GMT", "UTC");
  const city = timeZone === "UTC" ? "UTC" : timeZone.split("/").at(-1).replaceAll("_", " ");
  return `${normalizedOffset} · ${city}`;
}

const fixedShiftMilliseconds = Object.freeze({
  seconds: 1_000,
  minutes: 60_000,
  hours: 3_600_000,
  days: 86_400_000,
  weeks: 604_800_000,
});

export const relativeUnits = Object.freeze([
  "seconds",
  "minutes",
  "hours",
  "days",
  "weeks",
  "months",
  "years",
]);

function clampDay(year, month, day) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return Math.min(day, lastDay);
}

/** Shift an instant by a signed relative amount. Months/years follow the wall clock in `timeZone`. */
export function shiftMilliseconds(milliseconds, amount, unit, direction = "later", timeZone = "UTC") {
  const raw = Number(amount);
  if (!Number.isFinite(raw)) return null;
  const signed = (direction === "ago" ? -1 : 1) * Math.trunc(raw);
  if (signed === 0) return Math.trunc(milliseconds);

  if (Object.hasOwn(fixedShiftMilliseconds, unit)) {
    const next = Math.trunc(milliseconds) + signed * fixedShiftMilliseconds[unit];
    return Number.isSafeInteger(next) ? next : null;
  }

  if (unit !== "months" && unit !== "years") return null;

  const parts = partsAt(milliseconds, timeZone);
  let year = parts.year + (unit === "years" ? signed : 0);
  let monthIndex = parts.month - 1 + (unit === "months" ? signed : 0);
  year += Math.floor(monthIndex / 12);
  monthIndex = ((monthIndex % 12) + 12) % 12;
  const day = clampDay(year, monthIndex + 1, parts.day);
  const pad = (value) => String(value).padStart(2, "0");
  const nextValue = `${year}-${pad(monthIndex + 1)}-${pad(day)}T${pad(parts.hour)}:${pad(parts.minute)}:${pad(parts.second)}`;
  return millisecondsFromLocalDateTime(nextValue, timeZone);
}

/** Apply a chain of relative steps: date ± amount unit ± … */
export function applyRelativeSteps(milliseconds, steps, timeZone = "UTC") {
  let current = Math.trunc(milliseconds);
  if (!Number.isFinite(current)) return null;

  for (const step of steps) {
    const direction = step.operator === "subtract" ? "ago" : "later";
    const next = shiftMilliseconds(current, step.amount, step.unit, direction, timeZone);
    if (next === null) return null;
    current = next;
  }

  return current;
}
