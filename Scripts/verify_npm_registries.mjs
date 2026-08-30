import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const lockfiles = ["Tool/package-lock.json", "Website/package-lock.json"];
const approvedRegistry = "registry.npmjs.org";
const failures = [];

function validateResolvedURLs(value, location) {
  if (Array.isArray(value)) {
    value.forEach((entry, index) => validateResolvedURLs(entry, `${location}[${index}]`));
    return;
  }
  if (!value || typeof value !== "object") return;

  for (const [key, entry] of Object.entries(value)) {
    const entryLocation = `${location}.${key}`;
    if (key === "resolved" && typeof entry === "string" && /^https?:\/\//u.test(entry)) {
      const resolvedURL = new URL(entry);
      if (resolvedURL.protocol !== "https:" || resolvedURL.hostname !== approvedRegistry) {
        failures.push(`${entryLocation} uses unapproved registry ${resolvedURL.origin}`);
      }
    }
    validateResolvedURLs(entry, entryLocation);
  }
}

for (const relativePath of lockfiles) {
  const lockfile = JSON.parse(await fs.readFile(path.join(repositoryRoot, relativePath), "utf8"));
  validateResolvedURLs(lockfile, relativePath);
}

if (failures.length) {
  console.error("Unapproved npm registry URLs found in lockfiles:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
} else {
  console.log("Verified npm lockfiles use only the official HTTPS registry.");
}
