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
