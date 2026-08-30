export const REPOSITORY_URL = "https://github.com/rhevorn/machkit";
export const RELEASES_API_URL = "https://api.github.com/repos/rhevorn/machkit/releases?per_page=2";

/** Used only when CI does not bake VITE_RELEASE_TAG into the build. */
const DEFAULT_RELEASE_TAG = "v2.2.2";

export type ReleaseInfo = {
  tag: string;
  version: string;
  downloadURL: string;
};

export type GitHubReleaseAsset = {
  name?: string;
  browser_download_url?: string;
};

export type GitHubRelease = {
  tag_name?: string;
  assets?: GitHubReleaseAsset[];
};

export function releaseFromTag(
  tag: unknown,
  repositoryURL: string = REPOSITORY_URL,
): ReleaseInfo | null {
  const normalized = typeof tag === "string" ? tag.trim() : "";
  const version = normalized.replace(/^v/i, "");
  if (!normalized || !version) return null;

  const releaseTag = /^v/i.test(normalized) ? normalized : `v${version}`;
  const assetName = `MachKit-${version}-macOS.zip`;
  return Object.freeze({
    tag: releaseTag,
    version,
    downloadURL: `${repositoryURL}/releases/download/${encodeURIComponent(releaseTag)}/${encodeURIComponent(assetName)}`,
  });
}

function bakedReleaseTag(): string {
  const tag = import.meta.env?.VITE_RELEASE_TAG;
  return typeof tag === "string" ? tag.trim() : "";
}

/** Build-time download target. Prefer VITE_RELEASE_TAG from CI over the local default. */
export const fallbackRelease: ReleaseInfo = Object.freeze(
  releaseFromTag(bakedReleaseTag() || DEFAULT_RELEASE_TAG)!,
);

export function resolveReleaseDownload(
  release: GitHubRelease | null | undefined,
  fallback: ReleaseInfo = fallbackRelease,
): ReleaseInfo {
  const resolved = releaseFromTag(release?.tag_name);
  if (!resolved) return fallback;

  const assets = Array.isArray(release?.assets) ? release.assets : [];
  const assetName = `MachKit-${resolved.version}-macOS.zip`;
  const asset = assets.find((candidate) => candidate?.name === assetName);
  const assetURL = typeof asset?.browser_download_url === "string"
    ? asset.browser_download_url
    : "";

  return {
    tag: resolved.tag,
    version: resolved.version,
    downloadURL: assetURL || resolved.downloadURL,
  };
}

export function pickReleaseDownloads(
  releases: unknown,
  hardcodedFallback: ReleaseInfo = fallbackRelease,
): { latest: ReleaseInfo; previous: ReleaseInfo } {
  const list = Array.isArray(releases) ? (releases as GitHubRelease[]) : [];
  const previous = list[1] ? resolveReleaseDownload(list[1], hardcodedFallback) : hardcodedFallback;
  const latest = list[0] ? resolveReleaseDownload(list[0], previous) : previous;
  return { latest, previous };
}

export async function fetchLatestRelease({
  signal,
  fetchImpl = fetch,
}: {
  signal?: AbortSignal;
  fetchImpl?: typeof fetch;
} = {}): Promise<ReleaseInfo> {
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
