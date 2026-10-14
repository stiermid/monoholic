# Changelog

## 1.3.0 — Unreleased

### Added

- Accessible, keyboard-friendly scrolling for overflowing tables and code blocks, with configurable labels and hints.
- Sitemap support through `jekyll-sitemap` and a default `robots.txt` referencing the sitemap.
- Browser regression tests and clean, installed-gem consumer checks.

### Fixed

- Page-wide overflow from wide tables, long words, URLs, inline code, and plain or highlighted code blocks.
- Recursive menu heading levels leaking into sibling sections; untitled groups no longer skip heading levels.
- Escaping of custom heading ID prefixes and section labels.
- Homepage content now renders before menu sections.
- The 404 page is excluded from the sitemap.

### Changed

- Code blocks preserve indentation and source lines; tables retain native semantics with a wrapping fallback when JavaScript is unavailable.
- Release-tag publishing requires successful validation and a matching gem version, and publishes the exact checksum-verified package without rebuilding it.
- Release validation includes negative package and integrity tests and supports reruns.

[Compare changes since 1.2.0](https://github.com/stiermid/monoholic/compare/v1.2.0...v1.3.0).
