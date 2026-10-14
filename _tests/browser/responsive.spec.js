const { test, expect } = require("@playwright/test");

const widths = [320, 375, 768, 1280];

async function expectNoPageOverflow(page) {
  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    document: document.documentElement.scrollWidth,
  }));
  expect(dimensions.document).toBeLessThanOrEqual(dimensions.viewport + 1);
}

test.beforeEach(async ({ page }) => {
  // The network-independent fallback font must remain usable too.
  await page.route("https://fonts.googleapis.com/**", (route) => route.abort());
  await page.route("https://fonts.gstatic.com/**", (route) => route.abort());
});

for (const width of widths) {
  test(`homepage fits a ${width}px viewport`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(
      "Monoholic",
    );
    await expect(
      page.getByRole("link", { name: "An example post" }),
    ).toBeVisible();
    await expectNoPageOverflow(page);
  });

  test(`long text and code fit a ${width}px viewport`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/content.html");
    await expectNoPageOverflow(page);

    const blocks = page.locator("main pre");
    await expect(blocks).toHaveCount(2);
    for (const block of await blocks.all()) {
      await expect(block).toHaveCSS("white-space", "pre");
      const dimensions = await block.evaluate((element) => ({
        width: element.clientWidth,
        content: element.scrollWidth,
        text: element.textContent,
      }));
      expect(dimensions.content).toBeGreaterThan(dimensions.width);
      expect(dimensions.text).toContain(
        '\n  return "This deliberately long line',
      );
      await block.evaluate((element) => {
        element.scrollLeft = element.scrollWidth;
      });
      expect(
        await block.evaluate((element) => element.scrollLeft),
      ).toBeGreaterThan(0);
    }
  });
}
