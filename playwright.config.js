const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./_tests/browser",
  fullyParallel: true,
  workers: 2,
  retries: process.env.CI ? 2 : 0,
  reporter: "list",
  outputDir: "./_tests/.artifacts",
  use: {
    baseURL: "http://127.0.0.1:4173",
    browserName: "chromium",
    launchOptions: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
      ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH }
      : {},
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  webServer: {
    command:
      "bundle exec jekyll serve --source _tests/fixtures --config _tests/fixtures/_config.yml --destination _tests/.site --disable-disk-cache --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
  },
});
