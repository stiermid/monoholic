const { test, expect } = require("@playwright/test");

test.skip(({ browserName }) => browserName !== "firefox", "Firefox only");
test.use({
  launchOptions: {
    firefoxUserPrefs: {
      "font.size.variable.x-western": 32,
      "font.size.monospace.x-western": 32,
    },
  },
  javaScriptEnabled: false,
});

test("enlarged browser defaults reach body text", async ({ page }) => {
  await page.route("https://**/*", (route) => route.abort());
  await page.goto("/");
  await expect(page.locator("html")).toHaveCSS("font-size", "32px");
  await expect(page.locator("body")).toHaveCSS("font-size", "32px");
  const widths = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    document: document.documentElement.scrollWidth,
  }));
  expect(widths.document).toBeLessThanOrEqual(widths.viewport + 1);
});
