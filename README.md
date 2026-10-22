# Monoholic

[![Github license](https://img.shields.io/github/license/stiermid/monoholic?color=black)](https://www.gnu.org/licenses/gpl-3.0.txt)
[![GitHub release](https://img.shields.io/github/v/release/stiermid/monoholic?color=black)](https://github.com/stiermid/monoholic/releases)
[![Ruby](https://img.shields.io/badge/Ruby-gem-black?logo=ruby&logoColor=white)](https://rubygems.org/gems/monoholic)
[![Gem Version](https://img.shields.io/gem/v/monoholic?color=black)](https://rubygems.org/gems/monoholic)
[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-ready-black?logo=github&logoColor=white)](https://stiermid.github.io/monoholic)

A minimal, monochrome dark Jekyll theme

## Features

- Minimalist dark monochrome design
- Data-driven menu via `_data/menu.yml`
- Optional grayscale image filter
- SEO & RSS support
- SCSS source compiled via `jekyll-sass-converter`

## Installation

### Using RubyGems

1. Add this line to your Jekyll site's `Gemfile`:

```ruby
gem "monoholic"
```

2. Add this line to your Jekyll site's `_config.yml`:

```yaml
theme: monoholic
```

3. Execute:

```bash
$ bundle install
```

### Manual Installation (GitHub Pages)

For GitHub's built-in Jekyll build, add the following to `_config.yml`:

```yaml
title: "Your site"
description: "A short description of your site."
remote_theme: stiermid/monoholic@v1.3.0
url: "https://<user>.github.io"
baseurl: "/your-repo"
plugins:
  - jekyll-remote-theme
  - jekyll-feed
  - jekyll-seo-tag
  - jekyll-sitemap
```

Replace the user and repository placeholders. Use `baseurl: ""` for a user
site or a custom domain served at its root. Pinning a release keeps theme
updates explicit; omit `@v1.3.0` only if you want the repository's default
branch instead.

`jekyll-remote-theme` loads the theme. Feed and SEO tags require
`jekyll-feed` and `jekyll-seo-tag`; `jekyll-sitemap` generates the sitemap
and a default `robots.txt` when the site does not supply one.

Create a homepage, such as `index.md`:

```markdown
---
layout: home
---

Welcome to my site.
```

Also create `_data/menu.yml` in your site:

```yaml
entries:
  - title: all posts
    post_list: true
```

Native Jekyll 3.10 does not inherit a remote theme's `_data` directory, so
your site must supply its own menu. Add your posts under `_posts/` and
extend the menu using the options below.

> **Pages note:** Native Pages currently uses Jekyll 3.10.0 and Sass converter
> 1.5.2 with Ruby Sass. The `monoholic` gem requires Jekyll 4.4, so do not
> combine it with the native Pages bundle. Use `remote_theme` instead of
> `theme: monoholic` for that build. SCSS retains `@import` for this older
> Sass compiler.

| Method       | Jekyll | Build               |
| ------------ | ------ | ------------------- |
| RubyGem      | 4.4    | Local / custom CI   |
| Remote theme | 3.10   | Native GitHub Pages |

You can still deploy a Jekyll 4.4 gem-based site to Pages as static output
from a custom build workflow. The version restriction applies to GitHub's
built-in Jekyll build, not to static hosting.

For a full source checkout instead, fork this repository and adapt
`_config.yml` to your site.

## Usage

### Basic Setup

Once installed, build your site using the provided layouts (`default`, `home`, `page`, `post`).

On pages using the `home` layout, page content appears before the sections defined in `_data/menu.yml`.

### Configuration

Override the default settings in your `_config.yml`. Key theme configuration options:

```yaml
theme_config:
  back: "Back" # Text for backlink on post pages
  date_format: "%Y-%m-%d" # Date format for post metadata
  monochrome_images: true # Apply grayscale filter to images (default: true)
  footer: true # Show/hide site footer (default: true)
  skip_link_label: "Skip to content" # Keyboard skip-link text
  site_sections_label: "Site sections" # Accessible name of the homepage navigation
```

### Language and Interface Labels

The document's `<html lang>` uses the page's `lang` front matter, then the site's `lang` setting, then `en`. Use BCP 47 language tags such as `de`, `en-GB`, or `zh-Hant-TW`. Surrounding whitespace is trimmed; missing, empty, whitespace-only, or `false` values fall back to the next setting.

For example, configure a German site in `_config.yml`:

```yaml
lang: de
theme_config:
  skip_link_label: "Zum Inhalt"
  site_sections_label: "Seitenbereiche"
  back: "Zurück"
```

Override the document language for an individual page or post in its front matter:

```yaml
---
layout: page
lang: fr-CA
---
```

Declaring `lang` helps browsers and assistive technology interpret your content; it does not translate the content or interface automatically. Interface labels above are site-wide and rendered as plain text, not HTML. Missing or blank labels retain their English defaults so the skip link and navigation keep accessible names. Existing scroll labels and hints can also be translated under [Responsive Content](#responsive-content).

### Fediverse Creator tag

Monoholic supports `fediverse:creator` meta tag:

```yaml
fediverse_creator: "@username@social.example.com"
```

Setting `fediverse_creator` tag appends following tag to the site's header:

```html
<meta name="fediverse:creator" content="@username@social.example.com" />
```

[See Also](https://docs.joinmastodon.org/user/profile/#attribution)

### Menu Configuration

Monoholic uses a data-driven approach to its menu. Create or edit `_data/menu.yml` to define your site's navigation structure.

Example `_data/menu.yml`:

```yaml
entries:
  - title: about
    content: |
      <p>Your about me text here.</p>

  - title: all posts
    post_list: true
```

- `title`: The section header.
- `content`: Custom HTML or text for the menu section.
- `content_include`: Path relative to `_includes/` for a Markdown fragment with Liquid support (recommended for reusable content).
- `content_file`: Path to an existing Jekyll page (e.g., `about.md`) relative to your site root. Retained for compatibility; does not reliably evaluate Liquid.
- `post_list`: Set to `true` to auto-generate a list of your Jekyll posts under this section.

Use one content source per entry. If several are supplied, precedence is `content_include`, then `content_file`, then `content`.

#### Nested Menu Sections

Menu entries can contain nested `entries` to create recursive sub-sections:

```yaml
entries:
  - title: projects
    entries:
      - title: web
        content: |
          <p>Web projects here.</p>
      - title: archive
        post_list: true
```

Nesting can go as deep as needed — `menu.html` includes itself recursively for each `entries` array it encounters.

Top-level titles use `h2`. Each titled parent advances its children by one heading level, capped at `h6`. Entries with missing, empty, or whitespace-only titles are unlabelled groups: they render no heading and do not advance the heading level. Later siblings always retain their own level, regardless of the depth of earlier branches.

Each titled section is labelled by its heading. Heading IDs include the ancestor path and sibling index, so repeated titles remain distinct. When including multiple copies of a menu on the same page, give each copy a distinct `id_prefix` to avoid overlapping IDs:

```liquid
{% include menu.html collection=site.data.menu.entries level=2 id_prefix='primary' %}
{% include menu.html collection=site.data.menu.entries level=2 id_prefix='secondary' %}
```

#### Using External Content Files

For reusable content containing Liquid, create a Markdown fragment in your site's `_includes/` directory, for example `_includes/fragments/about.md`:

```liquid
Welcome to **{{ site.title }}**.

[Home]({{ '/' | relative_url }})
```

Reference it using `content_include`:

```yaml
entries:
  - title: about
    content_include: fragments/about.md
```

Jekyll renders Liquid first, then Monoholic converts the resulting Markdown to HTML once. Standard Liquid variables, filters, tags, and nested includes work without a custom plugin, including in safe mode. `page` refers to the page displaying the menu, not the fragment. Use `relative_url` for links that must work on project sites such as `/blog`.

Fragments must **not** have YAML front matter. They do not generate standalone pages. Paths are relative to `_includes/`, even when the menu appears on a nested page; missing files and invalid paths fail the build with Jekyll's include error rather than silently omitting content. Only include trusted, author-controlled files.

##### Existing `content_file` references

Existing page references remain supported:

```yaml
entries:
  - title: about
    content_file: about.md
```

The referenced file must be a Jekyll page with YAML front matter (an empty `---` block is sufficient) and must not be excluded from the build. Its Markdown content is embedded without its layout; the page can also generate its own standalone URL. Missing page references are silently omitted, preserving existing behavior.

`content_file` does not run a separate Liquid rendering pass. Results for Liquid expressions can depend on page rendering order, so use `content_include` whenever the content contains Liquid.

To migrate, move reusable content from `about.md` to `_includes/fragments/about.md`, remove its YAML front matter, and replace `content_file: about.md` with `content_include: fragments/about.md`. If you still need a standalone About page, keep `about.md` with its front matter and include the fragment in its body:

```liquid
{% include fragments/about.md %}
```

Use a Markdown page for this wrapper so Jekyll converts the included Markdown normally. Remove an old standalone page only if you no longer need its URL.

### Favicon

Monoholic ships with a default favicon. To use your own, replace the following files in your site's `assets/` directory:

- `assets/favicon.ico` — legacy browsers
- `assets/favicon.svg` — modern browsers
- `assets/apple-touch-icon.png` — iOS home screen (180×180)

### Stylesheet

Monoholic's stylesheet is written in SCSS and compiled at build time. The source lives in `_sass/` and is imported from `assets/css/style.scss`. Compilation is handled by `jekyll-sass-converter`, which is declared as a runtime dependency in the theme's `gemspec` — so no extra setup is required when you add `gem "monoholic"` to your `Gemfile`.

If you want to override or extend the styles, the recommended approach is to add your own partials in your site's `_sass/` directory and import them **after** the theme's entry point:

```scss
---
---

@import "monoholic";
@import "your-overrides";
```

Note: the theme uses `@import` (not `@use`) to stay compatible with GitHub Pages' Sass stack.

To override CSS custom properties (colors, spacing, fonts) without touching SCSS, redeclare the variables in your own stylesheet — they are exposed under `:root` in `_sass/_variables.scss`.

### Responsive Content

Body text defaults to `1rem`, following the browser's default font size
instead of fixing it at 16 pixels. When overriding `--font-size-base`, use
a relative value such as `1rem` or `1.125rem` to preserve that preference.

Long words, URLs, and inline code wrap when necessary. Plain and highlighted code blocks preserve indentation and source lines, scrolling horizontally inside the block instead of expanding the page.

The small, dependency-free `assets/js/content-scroll.js` script progressively enhances tables with scroll containers while preserving native table semantics. Overflowing tables and code blocks receive a keyboard tab stop, an accessible name, and a visible scrolling hint. These are updated when the viewport, content dimensions, or fonts change; fitting content does not add automatic tab stops.

Table captions are used as accessible names when available. Existing author-provided labels, descriptions, and tab indices are preserved. You can translate the default labels and hint in `_config.yml`:

```yaml
theme_config:
  table_scroll_label: "Table"
  code_scroll_label: "Code block"
  scroll_hint: "Scroll horizontally to see more."
```

Without JavaScript, tables use fixed-layout, wrapping cells, and code blocks still scroll. For especially wide tables that should scroll even without JavaScript, supply a `.table-scroll` wrapper with `tabindex="0"`, `role="region"`, and an accessible name (`aria-label` or `aria-labelledby`). The enhancement reuses that wrapper rather than nesting another one.

### Per-Page JavaScript

To load custom JavaScript files on a specific page, add a `custom_js` list to the page's front matter:

```yaml
---
layout: post
custom_js:
  - my-script
  - chart
---
```

Each entry is a filename (without `.js`) relative to `assets/js/`. The example above loads `assets/js/my-script.js` and `assets/js/chart.js` at the bottom of the page body.

## Contributing

### Running Tests

```sh
bundle install
npm ci
npx playwright install --with-deps chromium firefox webkit
bundle exec ruby _tests/release_workflow_test.rb
bundle exec ruby _tests/release_tag_test.rb
bundle exec ruby _tests/home_layout_test.rb
bundle exec ruby _tests/localization_test.rb
JEKYLL_SAFE=1 bundle exec ruby _tests/localization_test.rb
bundle exec ruby _tests/menu_layout_test.rb
JEKYLL_SAFE=1 bundle exec ruby _tests/menu_layout_test.rb
bundle exec ruby _tests/menu_content_test.rb
JEKYLL_SAFE=1 bundle exec ruby _tests/menu_content_test.rb
npm run test:browser
```

Browser tests build and serve an isolated fixture site. They cover Chromium, Firefox, and WebKit at 320px, 375px, 768px, and 1280px, including long text, plain and highlighted code, Markdown and HTML tables, keyboard scrolling, resizing, and JavaScript-disabled layouts. External fonts are blocked so the tests do not depend on Google Fonts being available.

Text-sizing checks enlarge the root font to 200% at each viewport width,
with and without JavaScript. A Firefox-specific test also changes the
actual browser default-font preference to 32 pixels. These are focused
regression checks, not a complete WCAG conformance audit.

Menu rendering checks cover branching recursion, deep nesting, untitled groups, repeated titles, unique IDs, escaped labels, and independent menu instances in normal and Jekyll safe mode. Browser tests also verify native heading and section semantics with JavaScript disabled.

Menu content checks build root and `/blog` sites in normal and safe mode. They cover Liquid-before-Markdown rendering, nested includes and host pages, recursive sections, literal Liquid examples, legacy content sources, and invalid include paths.

Localization checks cover language inheritance across all four layouts, page overrides, blank-value fallbacks, escaped attributes, translated labels, and unchanged skip-link destinations in normal and safe mode.

To run one browser, use `npm run test:browser -- --project=chromium`. You can also set `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` to use a locally installed Chromium binary. Generated sites, screenshots, and traces are ignored by Git; CI retains failure diagnostics for seven days.

### Native GitHub Pages Checks

The Pages tests use a separate Gemfile and lockfile so the theme's Jekyll 4.4
dependency cannot affect the native Pages graph. CI runs them on Ruby 3.3.
Install and run them with:

```sh
BUNDLE_GEMFILE=_tests/pages/Gemfile bundle install
BUNDLE_GEMFILE=_tests/pages/Gemfile bundle exec \
  ruby _tests/pages/consumer_test.rb
```

This bundle pins GitHub Pages 232, Jekyll 3.10.0, Sass converter 1.5.2, and
the other published Pages dependencies. The test invokes the real Pages
build command with its safe-mode configuration and default plugins. It
checks root and `/blog` sites, layouts, menu data, nested Liquid includes,
recursive headings, language settings, compiled CSS, scripts, favicons,
feeds, sitemap URLs, and rejection of a broken theme archive.

Only the theme-download HTTP response is supplied locally, using a ZIP of
the checkout. The real `jekyll-remote-theme` plugin downloads, extracts, and
loads it. No live GitHub requests or installed `monoholic` gem are used.
The generated lockfile retains Bundler's checksum format.

Review the [published dependency matrix](https://pages.github.com/versions/)
when updating this bundle. Update its Gemfile, lockfile, and expected versions
in `_tests/pages/consumer_test.rb` together.

### Release Validation

Pull requests and release-tag pushes run gem checks on Ruby 3.3 and 3.4,
plus the separate native Pages check on Ruby 3.3. Publishing requires all
three jobs to succeed and is restricted to pushed `v*` tags; pull requests
never publish. The tag must be `v` followed by the exact gem version in
`monoholic.gemspec`, including any RubyGems prerelease suffix. Update the
version metadata and lockfiles together before tagging.

Each gem-validation job builds the gem once and installs it into a temporary
gem home. A clean consumer's Gemfile declares only `monoholic`; Bundler resolves
its runtime dependencies from installed gems without downloading gems or
falling back to repository theme files. The checks run
`bundle exec jekyll build` for root and `/blog` sites and verify layouts,
compiled CSS, scripts, favicons, feeds, and URLs. Negative tests reject broken
packages and invalid versions. ERB must be declared as a runtime dependency,
even on hosts that provide it as a default gem; this is checked on both Rubies.

Consumer builds use resolved Ruby and gem executable paths, with no Jekyll
wrapper available on `PATH`. This also covers vendored CI installations
without relying on globally installed gem executables.

After validation, the Ruby 3.3 gem job uploads its gem and SHA-256 manifest
as a seven-day artifact; the other jobs do not upload a competing release
artifact. Once both gem jobs and native Pages pass, publishing downloads
those same bytes, verifies the checksum and package name/version, and pushes
the same gem to GitHub Packages and RubyGems—without checking out or rebuilding
the source. Rerunning validation replaces the artifact only after checks
succeed; if it has expired, rerun validation rather than just publishing.

Publishing keeps the existing authentication: `GITHUB_TOKEN` with package-write permission for GitHub Packages, and the repository's `RUBYGEMS_API_KEY` secret for RubyGems. Validation has read-only repository permissions; registry credentials are used only by publishing steps.

To exercise package checks locally without publishing (publisher verification requires Bash and `sha256sum` from GNU coreutils, matching the Linux CI runner):

```sh
mkdir -p _tests/.release
bundle exec gem build monoholic.gemspec --output _tests/.release/monoholic.gem
bundle exec ruby _tests/package_consumer_test.rb _tests/.release/monoholic.gem
bundle exec ruby _tests/package_consumer_negative_test.rb _tests/.release/monoholic.gem
(
  cd _tests/.release
  sha256sum monoholic.gem > monoholic.gem.sha256
)
bundle exec ruby _tests/package_integrity_test.rb _tests/.release/monoholic.gem _tests/.release/monoholic.gem.sha256
```

`package_integrity_test.rb` exercises the actual publisher verification recipe with valid, tampered, missing, and malformed inputs, plus a mismatched release tag. It never runs registry publishing commands. Release outputs are ignored by Git, and temporary package installations are removed after the checks finish.

Bug reports and pull requests are welcome on GitHub at [https://github.com/stiermid/monoholic](https://github.com/stiermid/monoholic). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

## License

This theme is available as open source under the terms of the [GNU General Public License v3.0 only](https://www.gnu.org/licenses/gpl.txt) (GPL-3.0-only).
