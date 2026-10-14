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
    includes = Array(params).map do |arguments|
      "{% include menu.html collection=site.data.menu.entries #{arguments} %}"
    end
    page.content = "<nav>#{includes.join}</nav>"
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
    assert_equal(
      entry_count(entries) * includes.length, sections.length,
      "#{name}: section count"
    )
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
    "safe" => ENV["JEKYLL_SAFE"] == "1",
    "whitelist" => %w[jekyll-feed jekyll-seo-tag jekyll-sitemap],
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

  checks.check(
    "sibling levels after recursive branches", [
      {
        "title" => "Parent", "entries" => [
          {
            "title" => "Child", "entries" => [
              { "title" => "Grandchild" }, { "title" => "Grandchild" }
            ]
          },
          { "title" => "Child" }
        ]
      },
      {
        "title" => "Next", "entries" => [
          { "title" => "Branch", "entries" => [{ "title" => "Leaf" }] },
          { "title" => "Branch" }
        ]
      },
      { "title" => "Last" }
    ],
    headings: [
      ["h2", "Parent"], ["h3", "Child"], ["h4", "Grandchild"],
      ["h4", "Grandchild"], ["h3", "Child"], ["h2", "Next"],
      ["h3", "Branch"], ["h4", "Leaf"], ["h3", "Branch"], ["h2", "Last"]
    ],
    ids: %w[
      parent-1 parent-1-child-1 parent-1-child-1-grandchild-1
      parent-1-child-1-grandchild-2 parent-1-child-2 next-2
      next-2-branch-1 next-2-branch-1-leaf-1 next-2-branch-2 last-3
    ]
  )

  checks.check(
    "untitled groups do not skip heading levels", [
      {
        "entries" => [
          {
            "title" => "Visible", "entries" => [
              { "title" => nil, "entries" => [
                { "title" => "Nested" }, { "title" => "Nested" }
              ] },
              { "title" => "After Group" }
            ]
          }
        ]
      },
      { "title" => "  ", "entries" => [
        { "title" => "Other" }, { "title" => "Other" }
      ] },
      { "title" => "Last" }
    ],
    headings: [
      ["h2", "Visible"], ["h3", "Nested"], ["h3", "Nested"],
      ["h3", "After Group"], ["h2", "Other"], ["h2", "Other"], ["h2", "Last"]
    ],
    ids: %w[
      section-1-visible-1 section-1-visible-1-section-1-nested-1
      section-1-visible-1-section-1-nested-2 section-1-visible-1-after-group-2
      section-2-other-1 section-2-other-2 last-3
    ]
  )

  deep = { "title" => "Depth 8" }
  7.downto(1) do |depth|
    deep = { "title" => "Depth #{depth}", "entries" => [
      deep, { "title" => "Sibling #{depth + 1}" }
    ] }
  end
  checks.check(
    "deep nesting caps headings without leaking to siblings",
    [deep, { "title" => "After depth" }],
    headings: [
      ["h2", "Depth 1"], ["h3", "Depth 2"], ["h4", "Depth 3"],
      ["h5", "Depth 4"], ["h6", "Depth 5"], ["h6", "Depth 6"],
      ["h6", "Depth 7"], ["h6", "Depth 8"], ["h6", "Sibling 8"],
      ["h6", "Sibling 7"], ["h6", "Sibling 6"], ["h6", "Sibling 5"],
      ["h5", "Sibling 4"], ["h4", "Sibling 3"], ["h3", "Sibling 2"],
      ["h2", "After depth"]
    ]
  )

  checks.check(
    "custom starting level survives recursion",
    [*nested, { "title" => "Sibling" }], params: "level=5",
    headings: [["h5", "Parent"], ["h6", "Child"], ["h5", "Sibling"]]
  )
  checks.check(
    "non-numeric heading level", [{ "title" => "Title" }],
    headings: [["h2", "Title"]], params: "level='invalid'"
  )
  checks.check(
    "negative heading level", [{ "title" => "Title" }],
    headings: [["h2", "Title"]], params: "level=-3"
  )
  checks.check(
    "parent ID takes precedence over prefix", nested,
    params: "level=3 parent_id='root' id_prefix='ignored'",
    headings: [["h3", "Parent"], ["h4", "Child"]],
    ids: %w[root-parent-1 root-parent-1-child-1]
  )
  checks.check(
    "escaped ID prefix", nested, params: "id_prefix='primary&\"secondary'",
    headings: [["h2", "Parent"], ["h3", "Child"]],
    ids: ['primary&"secondary-parent-1', 'primary&"secondary-parent-1-child-1']
  )
  checks.check(
    "independent menus on one page", nested,
    params: ["id_prefix='first' level=2", "id_prefix='second' level=4"],
    headings: [
      ["h2", "Parent"], ["h3", "Child"], ["h4", "Parent"], ["h5", "Child"]
    ],
    ids: %w[first-parent-1 first-parent-1-child-1 second-parent-1 second-parent-1-child-1]
  )

  mode = site.safe ? "safe mode" : "normal mode"
  puts "Menu layout checks passed (#{checks.count} cases, #{mode})."
end
