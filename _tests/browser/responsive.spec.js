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

  test(`tables stay inside a ${width}px viewport`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/tables.html");
    await expect(page.getByRole("table")).toHaveCount(4);
    await expect(page.locator(".table-scroll")).toHaveCount(4);
    await expectNoPageOverflow(page);
  });
}

test("overflowing tables support keyboard scrolling and resize", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto("/tables.html");
  const region = page.getByRole("region", {
    name: "Project comparison",
    exact: true,
  });
  await expect(region).toHaveAttribute("tabindex", "0");
  await expect(region).toHaveAccessibleDescription(
    "Scroll horizontally to see more.",
  );
  await page.getByRole("link", { name: "Monoholic", exact: true }).focus();
  await page.keyboard.press("Tab");
  await expect(region).toBeFocused();
  await expect(region).toHaveCSS("outline-style", "solid");
  await page.keyboard.press("ArrowRight");
  await expect
    .poll(() => region.evaluate((element) => element.scrollLeft))
    .toBeGreaterThan(0);

  const wrapper = page.locator("#comparison").locator("..");
  await page.setViewportSize({ width: 1280, height: 900 });
  await expect(wrapper).not.toHaveAttribute("tabindex", "0");
  await expect(wrapper).not.toHaveAttribute("role", "region");
  await expect
    .poll(() =>
      wrapper.evaluate((element) => element.nextElementSibling.hidden),
    )
    .toBe(true);
  await expectNoPageOverflow(page);

  await page.setViewportSize({ width: 320, height: 900 });
  await expect(wrapper).toHaveAttribute("tabindex", "0");
  await expect(wrapper).toHaveAttribute("role", "region");
});

test("fitting tables do not add unnecessary tab stops", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto("/tables.html");
  const wrapper = page.locator("#small-table").locator("..");
  await expect(wrapper).toHaveClass("table-scroll");
  await expect(wrapper).not.toHaveAttribute("tabindex", "0");
  await expect(wrapper).not.toHaveAttribute("role", "region");
});

test("code blocks support keyboard scrolling and content changes", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto("/content.html");
  const block = page.locator("main pre").first();
  await expect(block).toHaveAttribute("tabindex", "0");
  await expect(block).toHaveAccessibleName("Code block");
  await expect(block).toHaveAccessibleDescription(
    "Scroll horizontally to see more.",
  );
  await block.focus();
  await page.keyboard.press("ArrowRight");
  await expect
    .poll(() => block.evaluate((element) => element.scrollLeft))
    .toBeGreaterThan(0);

  const originalContent = await block.textContent();
  await block.evaluate((element) => {
    element.textContent = "short";
  });
  await expect(block).not.toHaveAttribute("tabindex", "0");
  await expect(block).not.toHaveAttribute("role", "region");
  await block.evaluate((element, text) => {
    element.textContent = text;
  }, originalContent);
  await expect(block).toHaveAttribute("tabindex", "0");
});

test("author accessibility attributes and existing wrappers are preserved", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto("/authored.html");
  const wrapper = page.locator(".table-scroll");
  await expect(wrapper).toHaveCount(1);
  await expect(wrapper).toHaveAttribute("tabindex", "0");
  await expect(wrapper).toHaveAttribute("role", "group");
  await expect(wrapper).toHaveAccessibleName("Custom table");
  await expect(wrapper).toHaveAccessibleDescription(
    "An author-provided description. Scroll horizontally to see more.",
  );

  // Loading the enhancement again must not nest wrappers or duplicate hints.
  await page.addScriptTag({ url: "/assets/js/content-scroll.js" });
  await expect(wrapper).toHaveCount(1);
  await expect(page.locator(".scroll-hint")).toHaveCount(1);
  await expect(
    page.getByRole("table", { name: "Original caption" }),
  ).toHaveCount(1);

  await wrapper.locator("td").evaluate((element) => {
    element.textContent = "short";
  });
  await expect(wrapper).toHaveAttribute(
    "aria-describedby",
    "table-description",
  );
  await expect(wrapper).toHaveAttribute("tabindex", "0");
  await expect(wrapper).toHaveAttribute("role", "group");
  await expect(wrapper).toHaveAccessibleName("Custom table");
});

test.describe("without JavaScript", () => {
  test.use({ javaScriptEnabled: false });
  for (const width of widths) {
    test(`content and tables fit a ${width}px viewport`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      for (const path of ["/content.html", "/tables.html"]) {
        await page.goto(path);
        await expectNoPageOverflow(page);
      }
      await expect(page.getByRole("table")).toHaveCount(4);
    });
  }
});
