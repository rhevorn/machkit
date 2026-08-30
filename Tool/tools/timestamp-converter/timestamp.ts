export type TimestampUnit = "nanoseconds" | "milliseconds" | "seconds";

export const units = Object.freeze({
  nanoseconds: { perMillisecond: 1_000_000n },
  milliseconds: { perMillisecond: 1n },
  seconds: { perMillisecond: null },
} as const satisfies Record<TimestampUnit, { perMillisecond: bigint | null }>);

export function timestampFromMilliseconds(milliseconds: number, unit: TimestampUnit): string {
  const value = BigInt(Math.trunc(milliseconds));
  if (unit === "seconds") return (value / 1_000n).toString();
  return (value * units[unit].perMillisecond).toString();
}

export function millisecondsFromTimestamp(rawValue: string, unit: TimestampUnit): number | null {
  const value = rawValue.trim();
  if (!/^-?\d+$/.test(value)) return null;

  try {
    const integer = BigInt(value);
    let milliseconds: bigint;
    if (unit === "seconds") milliseconds = integer * 1_000n;
    else milliseconds = integer / units[unit].perMillisecond;
    const result = Number(milliseconds);
    if (!Number.isSafeInteger(result) || Math.abs(result) > 8_640_000_000_000_000) return null;
    return result;
  } catch {
    return null;
  }
}

type DateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
};

function partsAt(milliseconds: number, timeZone: string): DateParts {
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
  ) as DateParts;
}

export function localDateTimeValue(milliseconds: number, timeZone: string): string {
  const parts = partsAt(milliseconds, timeZone);
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${parts.year}-${pad(parts.month)}-${pad(parts.day)}T${pad(parts.hour)}:${pad(parts.minute)}:${pad(parts.second)}`;
}

export function millisecondsFromLocalDateTime(value: string, timeZone: string): number | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/.exec(value);
  if (!match) return null;
  const [, year, month, day, hour, minute, second] = match.map(Number);
  const intendedUTC = Date.UTC(year!, month! - 1, day!, hour!, minute!, second!, 0);
  let candidate = intendedUTC;

  for (let iteration = 0; iteration < 3; iteration += 1) {
    const parts = partsAt(candidate, timeZone);
    const representedUTC = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second, 0);
    candidate -= representedUTC - intendedUTC;
  }

  return localDateTimeValue(candidate, timeZone) === value ? candidate : null;
}

export function formatDate(milliseconds: number, timeZone: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    timeZone,
    dateStyle: "medium",
    timeStyle: "medium",
  }).format(new Date(milliseconds));
}

/** Locale-friendly long date/time, e.g. Friday, August 28, 2026 at 17:31:00. */
export function formatReadableDate(milliseconds: number, timeZone: string, locale: string): string {
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
export function formatLocalDateTime(milliseconds: number, timeZone: string): string {
  return localDateTimeValue(milliseconds, timeZone).replace("T", " ");
}

function offsetMinutesAt(milliseconds: number, timeZone: string): number {
  const parts = partsAt(milliseconds, timeZone);
  const representedUTC = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  return Math.round((representedUTC - Math.trunc(milliseconds / 1_000) * 1_000) / 60_000);
}

function numericOffset(minutes: number, separator = ":"): string {
  if (minutes === 0 && separator === ":") return "Z";
  const sign = minutes < 0 ? "-" : "+";
  const absolute = Math.abs(minutes);
  const hours = String(Math.floor(absolute / 60)).padStart(2, "0");
  const remainder = String(absolute % 60).padStart(2, "0");
  return `${sign}${hours}${separator}${remainder}`;
}

export function formatISO8601(milliseconds: number): string {
  return new Date(milliseconds).toISOString();
}

export function formatRFC3339(milliseconds: number, timeZone: string): string {
  return `${localDateTimeValue(milliseconds, timeZone)}${numericOffset(offsetMinutesAt(milliseconds, timeZone))}`;
}

export function formatRFC2822(milliseconds: number, timeZone: string): string {
  const parts = partsAt(milliseconds, timeZone);
  const weekday = new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short" }).format(new Date(milliseconds));
  const month = new Intl.DateTimeFormat("en-US", { timeZone, month: "short" }).format(new Date(milliseconds));
  const pad = (value: number) => String(value).padStart(2, "0");
  const offset = numericOffset(offsetMinutesAt(milliseconds, timeZone), "");
  return `${weekday}, ${pad(parts.day)} ${month} ${parts.year} ${pad(parts.hour)}:${pad(parts.minute)}:${pad(parts.second)} ${offset}`;
}

export function timeZoneLabel(timeZone: string, locale: string, milliseconds = Date.now()): string {
  const offsetName = new Intl.DateTimeFormat(locale, {
    timeZone,
    timeZoneName: "longOffset",
  }).formatToParts(new Date(milliseconds)).find((part) => part.type === "timeZoneName")?.value || "UTC";
  const normalizedOffset = offsetName.replace("GMT", "UTC");
  const city = timeZone === "UTC" ? "UTC" : timeZone.split("/").at(-1)!.replaceAll("_", " ");
  return `${normalizedOffset} · ${city}`;
}

export type RelativeUnit = "seconds" | "minutes" | "hours" | "days" | "weeks" | "months" | "years";
export type RelativeDirection = "ago" | "later";
export type RelativeOperator = "add" | "subtract";

export type RelativeStep = {
  amount: number | string;
  unit: RelativeUnit;
  operator: RelativeOperator;
};

const fixedShiftMilliseconds = Object.freeze({
  seconds: 1_000,
  minutes: 60_000,
  hours: 3_600_000,
  days: 86_400_000,
  weeks: 604_800_000,
} as const satisfies Partial<Record<RelativeUnit, number>>);

export const relativeUnits = Object.freeze([
  "seconds",
  "minutes",
  "hours",
  "days",
  "weeks",
  "months",
  "years",
] as const satisfies readonly RelativeUnit[]);

function clampDay(year: number, month: number, day: number): number {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return Math.min(day, lastDay);
}

/** Shift an instant by a signed relative amount. Months/years follow the wall clock in `timeZone`. */
export function shiftMilliseconds(
  milliseconds: number,
  amount: number | string,
  unit: RelativeUnit,
  direction: RelativeDirection = "later",
  timeZone = "UTC",
): number | null {
  const raw = Number(amount);
  if (!Number.isFinite(raw)) return null;
  const signed = (direction === "ago" ? -1 : 1) * Math.trunc(raw);
  if (signed === 0) return Math.trunc(milliseconds);

  if (Object.hasOwn(fixedShiftMilliseconds, unit)) {
    const next = Math.trunc(milliseconds) + signed * fixedShiftMilliseconds[unit as keyof typeof fixedShiftMilliseconds];
    return Number.isSafeInteger(next) ? next : null;
  }

  if (unit !== "months" && unit !== "years") return null;

  const parts = partsAt(milliseconds, timeZone);
  let year = parts.year + (unit === "years" ? signed : 0);
  let monthIndex = parts.month - 1 + (unit === "months" ? signed : 0);
  year += Math.floor(monthIndex / 12);
  monthIndex = ((monthIndex % 12) + 12) % 12;
  const day = clampDay(year, monthIndex + 1, parts.day);
  const pad = (value: number) => String(value).padStart(2, "0");
  const nextValue = `${year}-${pad(monthIndex + 1)}-${pad(day)}T${pad(parts.hour)}:${pad(parts.minute)}:${pad(parts.second)}`;
  return millisecondsFromLocalDateTime(nextValue, timeZone);
}

/** Apply a chain of relative steps: date ± amount unit ± … */
export function applyRelativeSteps(
  milliseconds: number,
  steps: readonly RelativeStep[],
  timeZone = "UTC",
): number | null {
  let current = Math.trunc(milliseconds);
  if (!Number.isFinite(current)) return null;

  for (const step of steps) {
    const direction: RelativeDirection = step.operator === "subtract" ? "ago" : "later";
    const next = shiftMilliseconds(current, step.amount, step.unit, direction, timeZone);
    if (next === null) return null;
    current = next;
  }

  return current;
}
