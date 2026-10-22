const { test, expect } = require("@playwright/test");

const widths = [320, 375, 768, 1280];
const paths = [
  "/",
  "/content.html",
  "/tables.html",
  "/2026/01/01/example.html",
];

test.beforeEach(async ({ page }) => {
  await page.route("https://**/*", (route) => route.abort());
});

async function expectNoPageOverflow(page) {
  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    document: document.documentElement.scrollWidth,
  }));
  expect(dimensions.document).toBeLessThanOrEqual(dimensions.viewport + 1);
}

async function enlargeText(page) {
  // Change CSS at the network boundary so this also works without scripts.
  await page.route("**/assets/css/style.css", async (route) => {
    const response = await route.fetch();
    const css = await response.text();
    await route.fulfill({
      response,
      body: `${css}\nhtml { font-size: 200%; }`,
    });
  });
}

async function expectNoClippedText(page) {
  const clipped = await page
    .locator("body, .wrapper, main, main :is(p,li,h1,h2,h3,h4,h5,h6)")
    .evaluateAll((elements) => {
      const clips = (value) => value === "hidden" || value === "clip";
      return elements
        .filter((element) => {
          const style = getComputedStyle(element);
          return (
            (clips(style.overflowX) &&
              element.scrollWidth > element.clientWidth + 1) ||
            (clips(style.overflowY) &&
              element.scrollHeight > element.clientHeight + 1)
          );
        })
        .map((element) => element.tagName);
    });
  expect(clipped).toEqual([]);
}

test("default body text follows the browser root size", async ({ page }) => {
  await page.goto("/");
  const rootSize = await page.locator("html").evaluate((element) => {
    return getComputedStyle(element).fontSize;
  });
  await expect(page.locator("body")).toHaveCSS("font-size", rootSize);
});

for (const javaScriptEnabled of [true, false]) {
  test.describe(`text sizing with JavaScript ${javaScriptEnabled}`, () => {
    test.use({ javaScriptEnabled });

    for (const width of widths) {
      test(`200% text fits a ${width}px viewport`, async ({ page }) => {
        await page.setViewportSize({ width, height: 900 });
        await enlargeText(page);
        for (const path of paths) {
          await page.goto(path);
          await expect(page.locator("html")).toHaveCSS("font-size", "32px");
          await expect(page.locator("body")).toHaveCSS("font-size", "32px");
          await expect(page.locator("main")).toBeVisible();
          await expectNoPageOverflow(page);
          await expectNoClippedText(page);
          for (const block of await page.locator("main pre").all()) {
            await expect(block).toHaveCSS("white-space", "pre");
          }
        }
      });
    }

    test("showcase task checkboxes are named and read-only", async ({
      page,
    }) => {
      const tasks = [
        ["Initial theme setup", true],
        ["Fixed Prettier TOC formatting issue", true],
        ["Implement Dark Mode toggle", false],
        ["Optimize image loading", false],
      ];
      for (const enlarged of [false, true]) {
        if (enlarged) await enlargeText(page);
        const fontSize = enlarged ? "32px" : "16px";
        for (const width of widths) {
          await page.setViewportSize({ width, height: 900 });
          await page.goto("http://127.0.0.1:4174/2026/04/01/overview.html");
          await expect(page.getByRole("checkbox")).toHaveCount(tasks.length);
          for (const [name, checked] of tasks) {
            const checkbox = page.getByRole("checkbox", { name, exact: true });
            await expect(checkbox).toBeDisabled();
            await expect(checkbox).toBeChecked({ checked });
            await expect(checkbox).toHaveCSS("font-size", fontSize);
            await expect(checkbox).toHaveCSS("width", fontSize);
          }
          await expectNoPageOverflow(page);
          await expectNoClippedText(page);
        }
      }
    });
  });
}
