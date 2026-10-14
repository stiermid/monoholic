# frozen_string_literal: true

require "jekyll"
require "rexml/document"
require "tmpdir"

def assert_equal(expected, actual, message)
  return if expected == actual

  raise "#{message}: expected #{expected.inspect}, got #{actual.inspect}"
end

class MenuLayoutChecks
  attr_reader :count

  def initialize(site)
    @site = site
    @count = 0
  end

  def check(name, entries, headings:, params: "", ids: nil)
    @site.data["menu"] = { "entries" => entries }
    # Jekyll caches parsed Liquid templates by path; each case needs its own.
    page = Jekyll::PageWithoutAFile.new(
      @site, @site.source, "", "menu-#{@count}.html"
    )
    page.data["layout"] = "page"
    page.content = "<nav>{% include menu.html collection=site.data.menu.entries #{params} %}</nav>"
    output = Jekyll::Renderer.new(@site, page).run
    nav = output[/<nav\b[^>]*>.*?<\/nav>/m]
    raise "#{name}: missing menu" unless nav

    # Parse the rendered fragment, not the Liquid source, to check structure.
    document = REXML::Document.new(nav)
    elements = REXML::XPath.match(document, "//*")
    rendered_headings = elements.select do |element|
      element.name.match?(/\Ah\d+\z/)
    end
    actual = rendered_headings.map do |heading|
      [heading.name, heading.text.to_s.strip]
    end
    assert_equal(headings, actual, "#{name}: heading hierarchy")
    if ids
      actual_ids = rendered_headings.map { |heading| heading.attributes["id"] }
      assert_equal(ids, actual_ids, "#{name}: heading IDs")
    end

    all_ids = elements.filter_map { |element| element.attributes["id"] }
    assert_equal(all_ids.length, all_ids.uniq.length, "#{name}: unique IDs")
    if all_ids.any? { |id| id.empty? || id.match?(/\s/) }
      raise "#{name}: empty or whitespace-containing ID"
    end

    sections = elements.select { |element| element.name == "section" }
    assert_equal(entry_count(entries), sections.length, "#{name}: section count")
    sections.each do |section|
      heading = section.elements.to_a.find do |element|
        element.name.match?(/\Ah\d+\z/)
      end
      heading_id = heading && heading.attributes["id"]
      assert_equal(
        heading_id, section.attributes["aria-labelledby"], "#{name}: section label"
      )
    end

    @count += 1
    document
  end

  private

  def entry_count(entries)
    entries.sum { |entry| 1 + entry_count(entry.fetch("entries", [])) }
  end
end

Dir.mktmpdir("monoholic-menu-") do |source|
  File.write(File.join(source, "about.md"), "---\n---\nExternal **content**.\n")
  Dir.mkdir(File.join(source, "_posts"))
  File.write(
    File.join(source, "_posts", "2026-01-01-example.md"),
    "---\nlayout: post\ntitle: A post\n---\nPost content.\n"
  )
  config = Jekyll.configuration(
    "config" => [],
    "source" => source,
    "destination" => File.join(source, "_site"),
    "theme" => "monoholic",
    "ignore_theme_config" => true,
    "disable_disk_cache" => true,
    "future" => true,
    "baseurl" => "/blog",
    "url" => "https://example.test",
    "quiet" => true
  )
  site = Jekyll::Site.new(config)
  site.read
  checks = MenuLayoutChecks.new(site)

  checks.check("empty menu", [], headings: [])
  checks.check(
    "flat menu", [{ "title" => "About" }, { "title" => "Posts" }],
    headings: [["h2", "About"], ["h2", "Posts"]], ids: %w[about-1 posts-2]
  )
  checks.check(
    "repeated and punctuation-only titles",
    [{ "title" => "Projects" }, { "title" => "Projects" }, { "title" => "!!!" }],
    headings: [["h2", "Projects"], ["h2", "Projects"], ["h2", "!!!"]],
    ids: %w[projects-1 projects-2 section-3]
  )
  title = 'A <script> & "quote"'
  document = checks.check("escaped title", [{ "title" => title }], headings: [["h2", title]])
  assert_equal(
    [], REXML::XPath.match(document, "//script"), "title must not become markup"
  )
  nested = [{ "title" => "Parent", "entries" => [{ "title" => "Child" }] }]
  checks.check(
    "nested menu", nested, headings: [["h2", "Parent"], ["h3", "Child"]],
    ids: %w[parent-1 parent-1-child-1]
  )
  checks.check(
    "prefixed menu", nested, headings: [["h2", "Parent"], ["h3", "Child"]],
    params: "id_prefix='primary'", ids: %w[primary-parent-1 primary-parent-1-child-1]
  )
  checks.check(
    "minimum heading level", [{ "title" => "Title" }],
    headings: [["h2", "Title"]], params: "level=1"
  )
  checks.check(
    "maximum heading level", [{ "title" => "Title" }],
    headings: [["h6", "Title"]], params: "level=9"
  )

  document = checks.check("menu content and post list", [
    { "title" => "Inline", "content" => "<p>Inline content.</p>" },
    { "title" => "External", "content_file" => "about.md" },
    { "title" => "Archive", "post_list" => true }
  ], headings: [["h2", "Inline"], ["h2", "External"], ["h2", "Archive"]])
  assert_equal(
    "Inline content.", REXML::XPath.first(document, "//p").text,
    "inline content preserved"
  )
  assert_equal(
    "content", REXML::XPath.first(document, "//strong").text,
    "external Markdown preserved"
  )
  assert_equal(
    "/blog/2026/01/01/example.html",
    REXML::XPath.first(document, "//a").attributes["href"],
    "post link preserves baseurl"
  )

  puts "Menu layout checks passed (#{checks.count} cases)."
end
