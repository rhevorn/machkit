export const REPOSITORY_URL = "https://github.com/rhevorn/machkit";
export const RELEASES_API_URL = "https://api.github.com/repos/rhevorn/machkit/releases?per_page=2";

/** Last-resort hardcoded download when GitHub is unreachable. */
export const fallbackRelease = Object.freeze({
  tag: "v2.0.0",
  version: "2.0.0",
  downloadURL: `${REPOSITORY_URL}/releases/download/v2.0.0/MachKit-2.0.0-macOS.zip`,
});

export function resolveReleaseDownload(release, fallback = fallbackRelease) {
  const tag = typeof release?.tag_name === "string" ? release.tag_name.trim() : "";
  const version = tag.replace(/^v/i, "");
  if (!tag || !version) return fallback;

  const assets = Array.isArray(release.assets) ? release.assets : [];
  const assetName = `MachKit-${version}-macOS.zip`;
  const asset = assets.find((candidate) => candidate?.name === assetName);

  const assetURL = typeof asset?.browser_download_url === "string"
    ? asset.browser_download_url
    : "";
  const constructedURL = `${REPOSITORY_URL}/releases/download/${encodeURIComponent(tag)}/${encodeURIComponent(assetName)}`;

  return {
    tag,
    version,
    downloadURL: assetURL || constructedURL,
  };
}

export function pickReleaseDownloads(releases, hardcodedFallback = fallbackRelease) {
  const list = Array.isArray(releases) ? releases : [];
  const previous = list[1] ? resolveReleaseDownload(list[1], hardcodedFallback) : hardcodedFallback;
  const latest = list[0] ? resolveReleaseDownload(list[0], previous) : previous;
  return { latest, previous };
}

export async function fetchLatestRelease({ signal, fetchImpl = fetch } = {}) {
  const response = await fetchImpl(RELEASES_API_URL, {
    signal,
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!response.ok) throw new Error(`GitHub release request failed: ${response.status}`);
  const releases = await response.json();
  if (!Array.isArray(releases) || releases.length === 0) {
    throw new Error("GitHub release list was empty");
  }
  return pickReleaseDownloads(releases).latest;
}
