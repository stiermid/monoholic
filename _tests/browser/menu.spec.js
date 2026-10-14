const { test, expect } = require("@playwright/test");

// Menu semantics come from the generated HTML, not client-side JavaScript.
test.use({ javaScriptEnabled: false });

test.beforeEach(async ({ page }) => {
  await page.route("https://fonts.googleapis.com/**", (route) => route.abort());
  await page.route("https://fonts.gstatic.com/**", (route) => route.abort());
  await page.goto("/nested-menu.html");
});

test("recursive menus keep sibling levels and independent IDs", async ({
  page,
}) => {
  const expected = [
    ["H2", "Parent"],
    ["H3", "Child"],
    ["H4", "Leaf"],
    ["H3", "Child"],
    ["H2", "Next"],
    ["H3", "Branch"],
    ["H4", "Leaf"],
    ["H3", "Branch"],
    ["H2", "Group"],
    ["H3", "Deep group"],
    ["H3", "After group"],
    ["H2", "Last"],
  ];

  for (const name of ["Primary nested menu", "Secondary nested menu"]) {
    const menu = page.getByRole("navigation", { name, exact: true });
    await expect(menu.getByRole("heading")).toHaveCount(expected.length);
    const actual = await menu
      .locator(".section-title")
      .evaluateAll((headings) =>
        headings.map((heading) => [
          heading.tagName,
          heading.textContent.trim(),
        ]),
      );
    expect(actual).toEqual(expected);
  }

  const ids = await page
    .locator("[id]")
    .evaluateAll((elements) => elements.map((element) => element.id));
  expect(new Set(ids).size).toBe(ids.length);
  await expect(page.getByRole("heading", { level: 1 })).toHaveCount(1);
  const homeMenu = page.getByRole("navigation", { name: "Site sections" });
  await expect(homeMenu.getByRole("heading", { level: 2 })).toHaveCount(2);
});

test("titled sections retain accessible names and untitled groups stay unlabelled", async ({
  page,
}) => {
  const menu = page.getByRole("navigation", {
    name: "Primary nested menu",
    exact: true,
  });
  await expect(menu.getByRole("region")).toHaveCount(12);
  for (const heading of await menu.locator(".section-title").all()) {
    const section = heading.locator("..");
    const title = (await heading.textContent()).trim();
    await expect(section).toHaveAttribute(
      "aria-labelledby",
      await heading.getAttribute("id"),
    );
    // The theme's decorative heading prefix may also be announced by browsers.
    await expect(section).toHaveAccessibleName(new RegExp(`${title}$`));
  }

  const untitled = menu.locator("section:not([aria-labelledby])");
  await expect(untitled).toHaveCount(2);
  for (const group of await untitled.all()) {
    await expect(group.locator(":scope > .section-title")).toHaveCount(0);
  }
});
