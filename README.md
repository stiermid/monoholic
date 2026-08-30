# Monoholic

[![Github license](https://img.shields.io/github/license/stiermid/monoholic?color=black)](https://www.gnu.org/licenses/gpl-3.0.txt)
[![GitHub release](https://img.shields.io/github/v/release/stiermid/monoholic?color=black)](https://github.com/stiermid/monoholic/releases)
[![Ruby](https://img.shields.io/badge/Ruby-gem-black?logo=ruby&logoColor=white)](https://rubygems.org/gems/monoholic)
[![Gem Version](https://img.shields.io/gem/v/monoholic?color=black)](https://rubygems.org/gems/monoholic)
[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-ready-black?logo=github&logoColor=white)](https://stiermid.github.io/monoholic)

A minimal, monochrome dark Jekyll theme🧪

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

### Manual Installation

If you're running Jekyll without RubyGems or prefer to use GitHub Pages remote themes, update your `_config.yml`:

```yaml
remote_theme: stiermid/monoholic
```

Or, simply fork this repository, adapt the `_config.yml` according to your needs, and you're good to go!

## Usage

### Basic Setup

Once installed, build your site using the provided layouts (`default`, `home`, `page`, `post`).

### Configuration

Override the default settings in your `_config.yml`. Key theme configuration options:

```yaml
theme_config:
  back: ".." # Text for backlink on post pages
  date_format: "%Y%m%d" # Date format for post metadata
  monochrome_images: true # Apply grayscale filter to images (default: true)
  footer: true # Show/hide site footer (default: true)
```

### Fediverse Creator tag

Monoholic supports `fediverse:creator` meta tag:

```yaml
fediverse_creator: "@username@social.example.com"
```

Setting `fediverse_creator` tag appends following tag to the site's header:

```html
<meta name="fediverse:creator" content="@username@social.example.com">
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
- `content_file`: Path to an external markdown file (e.g., `about.md`) to load content from your root directory.
- `post_list`: Set to `true` to auto-generate a list of your Jekyll posts under this section.

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

#### Using External Content Files

You can reference external markdown files instead of inline content:

```yaml
entries:
  - title: about
    content_file: about.md
```

This will load and render the content from `about.md` in your site's root directory.

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

To override CSS custom properties (colors, spacing, fonts) without touching SCSS, redeclare the variables in your own stylesheet — they are exposed under `:root` in `_sass/_variables.scss`.

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

Bug reports and pull requests are welcome on GitHub at [https://github.com/stiermid/monoholic](https://github.com/stiermid/monoholic). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

## License

This theme is available as open source under the terms of the [GNU General Public License v3.0 only](https://www.gnu.org/licenses/gpl.txt) (GPL-3.0-only).
