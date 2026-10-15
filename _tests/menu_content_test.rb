# frozen_string_literal: true

require "fileutils"
require "jekyll"
require "rexml/document"
require "tmpdir"
require "yaml"

def assert_equal(expected, actual, message)
  return if expected == actual

  raise "#{message}: expected #{expected.inspect}, got #{actual.inspect}"
end

Dir.mktmpdir("monoholic-menu-content-") do |source|
  FileUtils.mkdir_p([
    File.join(source, "_includes", "fragments"),
    File.join(source, "_data"), File.join(source, "nested")
  ])
  File.write(File.join(source, "_includes", "fragments", "intro.md"), <<~LIQUID)
    **{{ site.title }}** for {{ page.title }}.

    {% assign fragment_home = '/' | relative_url %}
    [Home]({{ fragment_home }})

    {% include fragments/link.md %}

    ---

    ```liquid
    {% raw %}{{ site.title }}{% endraw %}
    ```
  LIQUID
  File.write(
    File.join(source, "_includes", "fragments", "link.md"),
    "[About]({{ '/about.html' | relative_url }})\n"
  )
  File.write(File.join(source, "legacy.md"), "---\n---\nLegacy **Markdown**.\n")
  File.write(File.join(source, "about.md"), <<~LIQUID)
    ---
    layout: page
    title: About host
    ---
    {% include fragments/intro.md %}
  LIQUID
  entries = [
    {
      "title" => "Parent", "content_include" => "fragments/intro.md",
      "content_file" => "legacy.md", "content" => "Ignored inline content.",
      "entries" => [
        { "title" => "Child", "content_include" => "fragments/intro.md" }
      ]
    },
    { "title" => "Sibling", "content_include" => "fragments/intro.md" },
    {
      "title" => "Legacy", "content_file" => "legacy.md",
      "content" => "Ignored legacy fallback."
    },
    { "title" => "Inline", "content" => "<p>Inline content.</p>" },
    { "title" => "Missing legacy", "content_file" => "missing.md" }
  ]
  File.write(File.join(source, "_data", "menu.yml"), { "entries" => entries }.to_yaml)
  { "index.md" => "Root host", "nested/index.md" => "Nested host" }.each do |path, title|
    File.write(File.join(source, path), "---\nlayout: home\ntitle: #{title}\n---\n")
  end

  ["", "/blog"].each_with_index do |baseurl, index|
    config = Jekyll.configuration(
      "config" => [], "source" => source,
      "destination" => File.join(source, "_site-#{index}"),
      "theme" => "monoholic", "ignore_theme_config" => true,
      "safe" => ENV["JEKYLL_SAFE"] == "1",
      "whitelist" => %w[jekyll-feed jekyll-seo-tag jekyll-sitemap],
      "disable_disk_cache" => true, "title" => "Content test",
      "url" => "https://example.test", "baseurl" => baseurl, "quiet" => true
    )
    site = Jekyll::Site.new(config)
    site.process

    { "index.html" => "Root host", "nested/index.html" => "Nested host" }.each do |path, title|
      output = File.read(File.join(site.dest, path))
      nav = output[/<nav\b[^>]*>.*?<\/nav>/m]
      raise "#{path}: missing menu" unless nav

      document = REXML::Document.new(nav)
      links = REXML::XPath.match(document, "//a").map { |link| link.attributes["href"] }
      assert_equal(
        ["#{baseurl}/", "#{baseurl}/about.html"] * 3, links,
        "#{path}: Liquid URLs render before Markdown, including nested includes"
      )
      assert_equal(
        ["Content test"] * 3 + ["Markdown"],
        REXML::XPath.match(document, "//strong").map(&:text),
        "#{path}: include Markdown and legacy content render once"
      )
      assert_equal(3, nav.scan("for #{title}.").length, "#{path}: host page context")
      assert_equal(3, REXML::XPath.match(document, "//hr").length, "fragment separators preserved")
      assert_equal(
        ["{{ site.title }}\n"] * 3,
        REXML::XPath.match(document, "//code").map do |code|
          REXML::XPath.match(code, ".//text()").map(&:value).join
        end,
        "raw Liquid examples are not evaluated a second time"
      )
      assert_equal(
        %w[h2 h3 h2 h2 h2 h2],
        REXML::XPath.match(document, "//section/*").filter_map do |element|
          element.name if element.name.match?(/\Ah[2-6]\z/)
        end,
        "fragment includes do not corrupt recursive menu state"
      )
      assert_equal(false, nav.include?("Ignored inline content."), "include takes precedence")
      assert_equal(false, nav.include?("Ignored legacy fallback."), "legacy file takes precedence over inline content")
      assert_equal(true, nav.include?("<p>Inline content.</p>"), "inline content remains supported")
      assert_equal(
        false, File.exist?(File.join(site.dest, "fragments", "intro.html")),
        "include fragments do not create standalone pages"
      )
    end

    about = File.read(File.join(site.dest, "about.html"))
    assert_equal(
      true, about.include?("<strong>Content test</strong> for About host."),
      "a standalone Markdown page can share the fragment after migration"
    )
    assert_equal(
      true, about.include?("href=\"#{baseurl}/\""),
      "standalone wrapper links preserve baseurl"
    )

    ["fragments/missing.md", "../legacy.md"].each_with_index do |include_path, failure_index|
      site.data["menu"] = { "entries" => [{ "content_include" => include_path }] }
      page = Jekyll::PageWithoutAFile.new(site, source, "", "invalid-#{failure_index}.html")
      page.data["layout"] = "home"
      begin
        Jekyll::Renderer.new(site, page).run
      rescue IOError, ArgumentError => error
        raise "Unhelpful include error: #{error.message}" unless error.message.include?(include_path)
        next
      end
      raise "Invalid include #{include_path.inspect} must fail the build"
    end
  end

  mode = ENV["JEKYLL_SAFE"] == "1" ? "safe mode" : "normal mode"
  puts "Menu content checks passed (root and /blog sites, nested hosts, #{mode})."
end
