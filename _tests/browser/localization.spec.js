const { test, expect } = require("@playwright/test");

test.use({ javaScriptEnabled: false });

test.beforeEach(async ({ page }) => {
  await page.route("https://fonts.googleapis.com/**", (route) => route.abort());
  await page.route("https://fonts.gstatic.com/**", (route) => route.abort());
});

test("generated pages inherit the site language unless front matter overrides it", async ({
  page,
}) => {
  for (const path of ["/", "/content.html", "/2026/01/01/example.html"]) {
    await page.goto(path);
    await expect(page.locator("html")).toHaveAttribute("lang", "en-GB");
  }
  await page.goto("/language-override.html");
  await expect(page.locator("html")).toHaveAttribute("lang", "en-US");
});

test("configured labels retain accessible names and keyboard skip navigation", async ({
  page,
}) => {
  await page.goto("/");
  await expect(
    page.getByRole("navigation", {
      name: "Site sections & links",
      exact: true,
    }),
  ).toBeVisible();
  const skip = page.getByRole("link", {
    name: "Skip to main content",
    exact: true,
  });
  await expect(skip).toHaveAttribute("href", "#main");
  await expect(skip).not.toBeInViewport();
  await page.keyboard.press("Tab");
  await expect(skip).toBeFocused();
  await expect(skip).toBeInViewport();
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/#main$/);
  await expect(page.locator("main#main")).toBeInViewport();
});
