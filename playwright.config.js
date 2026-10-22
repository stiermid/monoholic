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
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: {
        browserName: "chromium",
        launchOptions: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
          ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH }
          : {},
      },
    },
    { name: "firefox", use: { browserName: "firefox" } },
    { name: "webkit", use: { browserName: "webkit" } },
  ],
  webServer: [
    {
      command: [
        "bundle exec jekyll serve",
        "--source _tests/fixtures --config _tests/fixtures/_config.yml",
        "--destination _tests/.site --disable-disk-cache --no-watch",
        "--host 127.0.0.1 --port 4173",
      ].join(" "),
      url: "http://127.0.0.1:4173",
      reuseExistingServer: false,
    },
    {
      command: [
        "bundle exec jekyll serve --config _config.yml --baseurl ''",
        "--destination _tests/.demo-site --disable-disk-cache --no-watch",
        "--host 127.0.0.1 --port 4174",
      ].join(" "),
      url: "http://127.0.0.1:4174",
      reuseExistingServer: false,
    },
  ],
});
