import { expect, test } from "@playwright/test";

type WindowClass = "compact" | "regular" | "wide";

const windowSizes: Record<WindowClass, {
  minimum: { width: number; height: number };
  default: { width: number; height: number };
}> = {
  compact: { minimum: { width: 640, height: 480 }, default: { width: 720, height: 560 } },
  regular: { minimum: { width: 720, height: 520 }, default: { width: 840, height: 640 } },
  wide: { minimum: { width: 860, height: 580 }, default: { width: 1040, height: 720 } },
};

const tools: Array<{ id: string; windowClass: WindowClass }> = [
  { id: "json-formatter", windowClass: "wide" },
  { id: "timestamp-converter", windowClass: "compact" },
  { id: "codec", windowClass: "compact" },
  { id: "string-generator", windowClass: "compact" },
  { id: "hosts-manager", windowClass: "regular" },
  { id: "url-lab", windowClass: "compact" },
  { id: "regex-lab", windowClass: "compact" },
  { id: "text-diff", windowClass: "wide" },
  { id: "number-base", windowClass: "compact" },
  { id: "cron-expression", windowClass: "compact" },
  { id: "ip-cidr", windowClass: "regular" },
  { id: "color-lab", windowClass: "regular" },
  { id: "image-process", windowClass: "wide" },
  { id: "qr-code", windowClass: "compact" },
  { id: "jwt-lab", windowClass: "regular" },
  { id: "chmod-lab", windowClass: "compact" },
  { id: "cert-lab", windowClass: "regular" },
  { id: "curl-lab", windowClass: "wide" },
  { id: "port-scan", windowClass: "regular" },
];

for (const tool of tools) {
  for (const appearance of ["light", "dark"] as const) {
    const size = appearance === "light"
      ? windowSizes[tool.windowClass].minimum
      : windowSizes[tool.windowClass].default;

    test(`${tool.id} renders at ${appearance === "light" ? "minimum" : "default"} size in ${appearance}`, async ({ page }) => {
      const pageErrors: string[] = [];
      page.on("pageerror", (error) => pageErrors.push(error.message));
      await page.setViewportSize(size);
      await page.goto(`/tools/${tool.id}/?locale=en&appearance=${appearance}`, { waitUntil: "networkidle" });

      await expect(page.locator("main")).toHaveCount(1);
      await expect(page).toHaveTitle(/\S/);
      await expect(page.getByText("This tool could not be opened", { exact: true })).toHaveCount(0);
      expect(pageErrors).toEqual([]);

      const layout = await page.evaluate(() => ({
        viewportWidth: document.documentElement.clientWidth,
        documentWidth: document.documentElement.scrollWidth,
        bodyWidth: document.body.scrollWidth,
      }));
      expect(Math.max(layout.documentWidth, layout.bodyWidth)).toBeLessThanOrEqual(layout.viewportWidth + 1);

      const controls = page.locator([
        "button:visible",
        "input:visible:not([type='hidden'])",
        "select:visible",
        "textarea:visible",
        "[role='radio']:visible",
        "[role='separator']:visible",
        "[role='slider']:visible",
      ].join(", "));
      for (let index = 0; index < await controls.count(); index += 1) {
        await expect(controls.nth(index), `${tool.id} control ${index + 1} needs an accessible name`).toHaveAccessibleName(/\S/);
      }
    });
  }
}
