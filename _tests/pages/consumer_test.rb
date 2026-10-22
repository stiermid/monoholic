# frozen_string_literal: true

require "bundler/setup"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

def assert_pages(condition, message)
  raise message unless condition
end

# These are the published native Pages versions, not the theme gem's graph.
{
  "github-pages" => "232",
  "jekyll" => "3.10.0",
  "jekyll-sass-converter" => "1.5.2",
  "sass" => "3.7.4",
  "jekyll-remote-theme" => "0.4.3",
  "jekyll-seo-tag" => "2.8.0",
  "jekyll-feed" => "0.17.0",
  "jekyll-sitemap" => "1.4.0",
  "nokogiri" => "1.16.7"
}.each do |name, version|
  actual = Gem.loaded_specs[name]&.version.to_s
  assert_pages(
    actual == version,
    "Expected #{name} #{version}, got #{actual.inspect}; use the Pages Gemfile"
  )
end
assert_pages(
  !Gem.loaded_specs.key?("monoholic"),
  "The Pages consumer must not activate the Jekyll 4.4 theme gem"
)

require "nokogiri"
require "zip"

def theme_archive(repository, destination, omit: [])
  files, status = Open3.capture2("git", "ls-files", "-z", chdir: repository)
  assert_pages(status.success?, "Could not enumerate the checkout files")
  Zip::OutputStream.open(destination) do |zip|
    directories = {}
    files.split("\0").sort.each do |path|
      next if omit.include?(path)
      file = File.join(repository, path)
      next unless File.file?(file)

      entry = "monoholic-pages-test/#{path}"
      parents = entry.split("/")[0...-1]
      parents.each_index do |index|
        directory = "#{parents.take(index + 1).join('/')}/"
        next if directories[directory]

        zip.put_next_entry(directory)
        directories[directory] = true
      end
      zip.put_next_entry(entry)
      zip.write(File.binread(file))
    end
  end
end

def build_pages(source, destination, archive)
  Open3.capture2e(
    { "JEKYLL_ENV" => "production", "MONOHOLIC_THEME_ARCHIVE" => archive },
    RbConfig.ruby, "-r", File.expand_path("remote_theme_fixture.rb", __dir__),
    Gem.bin_path("github-pages", "github-pages"), "build",
    "--source", source, "--destination", destination,
    chdir: source
  )
end

def document(destination, path)
  Nokogiri::HTML(File.read(File.join(destination, path)))
end

repository = File.expand_path("../..", __dir__)
fixtures = File.join(repository, "_tests", "fixtures")
Dir.mktmpdir("monoholic-pages-") do |root|
  source = File.join(root, "site")
  FileUtils.mkdir_p(source)
  FileUtils.cp_r(File.join(fixtures, "."), source)
  FileUtils.cp(
    File.join(repository, "_posts", "2026-04-01-overview.md"),
    File.join(source, "_posts")
  )
  %w[_layouts _sass assets].each do |path|
    assert_pages(
      !File.exist?(File.join(source, path)),
      "Consumer fixtures must not shadow theme #{path}"
    )
  end

  # Native Pages must not execute arbitrary site plugins.
  FileUtils.mkdir_p(File.join(source, "_plugins"))
  File.write(File.join(source, "_plugins", "forbidden.rb"), <<~RUBY)
    raise "A local plugin ran despite native Pages safe mode"
  RUBY
  File.write(File.join(source, "default.md"), <<~MARKDOWN)
    ---
    layout: default
    ---
    Direct default-layout content.
  MARKDOWN
  fragment = File.join(source, "_includes", "fragments", "intro.md")
  File.open(fragment, "a") do |file|
    file.puts "\n{% include fragments/feed.md %}"
  end
  File.write(File.join(source, "_includes", "fragments", "feed.md"), <<~LIQUID)
    [RSS]({{ '/feed.xml' | relative_url }})
  LIQUID

  config = YAML.load_file(File.join(fixtures, "_config.yml"))
  config.delete("theme")
  config.delete("ignore_theme_config")
  config.merge!(
    "title" => "Pages consumer",
    "description" => "Native GitHub Pages compatibility fixture.",
    "url" => "https://example.test",
    "remote_theme" => "stiermid/monoholic@pages-test",
    "repository" => "stiermid/monoholic",
    "plugins" => %w[
      jekyll-remote-theme jekyll-feed jekyll-seo-tag jekyll-sitemap
    ]
  )
  archive = File.join(root, "theme.zip")
  theme_archive(repository, archive)

  ["", "/blog"].each_with_index do |baseurl, index|
    config["baseurl"] = baseurl
    File.write(File.join(source, "_config.yml"), YAML.dump(config))
    destination = File.join(root, "output-#{index}")
    output, status = build_pages(source, destination, archive)
    assert_pages(
      status.success?, "Native Pages consumer build failed:\n#{output}"
    )

    %w[
      index.html content.html default.html 2026/01/01/example.html
    ].each do |path|
      page = document(destination, path)
      assert_pages(
        page.at_css("main#main"), "Missing default layout in #{path}"
      )
      assert_pages(
        page.at_css("html")["lang"] == "en-GB", "Language in #{path}"
      )
      assert_pages(
        page.at_css('link[href$="/assets/css/style.css"]')["href"] ==
          "#{baseurl}/assets/css/style.css",
        "Stylesheet URL in #{path} ignores baseurl"
      )
      assert_pages(
        page.at_css('script[src$="content-scroll.js"]')["src"] ==
          "#{baseurl}/assets/js/content-scroll.js",
        "Script URL in #{path} ignores baseurl"
      )
    end

    home = document(destination, "index.html")
    assert_pages(
      home.at_css('link[rel="canonical"]')["href"] ==
        "https://example.test#{baseurl}/",
      "Incorrect canonical URL"
    )
    assert_pages(
      home.at_css("nav p a strong")&.text == "Pages consumer",
      "Menu fragment did not render Liquid before Markdown"
    )
    %w[content.html feed.xml 2026/01/01/example.html].each do |path|
      assert_pages(
        home.at_css("nav a[href='#{baseurl}/#{path}']"),
        "Menu link to #{path} is missing or ignores baseurl"
      )
    end
    assert_pages(
      home.text.include?("Welcome to the responsive content test site."),
      "Home layout dropped page content"
    )
    assert_pages(
      document(destination, "language-override.html").at_css("html")["lang"] ==
        "en-US",
      "Page language override was ignored"
    )
    assert_pages(
      document(destination, "content.html").css("main pre").length == 2,
      "Plain and highlighted code must both render"
    )
    assert_pages(
      document(destination, "tables.html").css("main table").length == 4,
      "Markdown and HTML tables must both render"
    )

    showcase = document(destination, "2026/04/01/overview.html")
    boxes = showcase.css('.task-list input[type="checkbox"]')
    names = boxes.map do |box|
      label = box.ancestors("label").first
      assert_pages(label, "Task checkboxes must have native labels")
      assert_pages(label.css("input").length == 1, "One checkbox per label")
      assert_pages(box.key?("disabled"), "Showcase tasks must be read-only")
      label.text.split.join(" ")
    end
    assert_pages(
      names == [
        "Initial theme setup", "Fixed Prettier TOC formatting issue",
        "Implement Dark Mode toggle", "Optimize image loading"
      ],
      "Task labels must retain their visible names"
    )
    assert_pages(
      boxes.map { |box| box.key?("checked") } == [true, true, false, false],
      "Task completion states must be preserved"
    )

    nested = document(destination, "nested-menu.html")
    ids = nested.css("[id]").map { |node| node["id"] }
    assert_pages(ids.uniq == ids, "Recursive menus produced duplicate IDs")
    %w[Primary Secondary].each do |prefix|
      menu = nested.at_css("nav[aria-label='#{prefix} nested menu']")
      levels = menu.css(".section-title").map(&:name)
      assert_pages(
        levels == %w[h2 h3 h4 h3 h2 h3 h4 h3 h2 h3 h3 h2],
        "Recursive menu heading levels are incorrect"
      )
    end

    %w[
      assets/css/style.css assets/js/content-scroll.js assets/favicon.ico
      assets/favicon.svg assets/apple-touch-icon.png feed.xml sitemap.xml
      robots.txt
    ].each do |path|
      assert_pages(File.size?(File.join(destination, path)), "Missing #{path}")
    end
    css = File.read(File.join(destination, "assets", "css", "style.css"))
    assert_pages(
      css.match?(/--font-size-base:\s*1rem;/),
      "The default body font size must respect the browser root size"
    )
    assert_pages(
      css.include?(":root") && css.include?(".table-scroll") &&
        !css.match?(/@(?:use|import)\b/),
      "Ruby Sass did not compile the remote theme stylesheet"
    )
    %w[feed.xml sitemap.xml].each do |path|
      xml = File.read(File.join(destination, path))
      assert_pages(
        xml.include?("https://example.test#{baseurl}/2026/01/01/example.html"),
        "#{path} post URL ignores baseurl"
      )
    end
  end

  broken_archive = File.join(root, "missing-sass.zip")
  theme_archive(repository, broken_archive, omit: ["_sass/_variables.scss"])
  output, status = build_pages(
    source, File.join(root, "broken"), broken_archive
  )
  import_error = "File to import not found or unreadable"
  assert_pages(
    !status.success? && output.include?(import_error),
    "Broken remote Sass must fail without checkout fallback:\n#{output}"
  )
end

puts "Native Pages consumer checks passed (root, /blog, and broken ZIP)."
