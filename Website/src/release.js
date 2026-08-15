export const REPOSITORY_URL = "https://github.com/rhevorn/machkit";
export const LATEST_RELEASE_API_URL = "https://api.github.com/repos/rhevorn/machkit/releases/latest";

export const fallbackRelease = Object.freeze({
  tag: "v1.2.1",
  version: "1.2.1",
  downloadURL: `${REPOSITORY_URL}/releases/download/v1.2.1/MachKit-1.2.1-macOS.zip`,
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

export async function fetchLatestRelease({ signal, fetchImpl = fetch } = {}) {
  const response = await fetchImpl(LATEST_RELEASE_API_URL, {
    signal,
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!response.ok) throw new Error(`GitHub release request failed: ${response.status}`);
  return resolveReleaseDownload(await response.json());
}
