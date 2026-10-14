# frozen_string_literal: true

require "jekyll"
require "tmpdir"

Dir.mktmpdir("monoholic-home-") do |source|
  config = Jekyll.configuration(
    "config" => [],
    "source" => source,
    "destination" => File.join(source, "_site"),
    "theme" => "monoholic",
    "ignore_theme_config" => true,
    "disable_disk_cache" => true,
    "quiet" => true
  )
  site = Jekyll::Site.new(config)
  site.read
  site.data["menu"] = {
    "entries" => [{ "title" => "Menu section", "content" => "<p>Menu content</p>" }]
  }

  {
    "markdown.md" => ["Welcome **home**.", "<p>Welcome <strong>home</strong>.</p>"],
    "html.html" => ["<p>Welcome home.</p>", "<p>Welcome home.</p>"],
    "empty.md" => ["", ""]
  }.each do |name, (content, expected)|
    page = Jekyll::PageWithoutAFile.new(site, source, "", name)
    page.data["layout"] = "home"
    page.content = content
    output = Jekyll::Renderer.new(site, page).run
    main = output[/<main\b[^>]*>(.*?)<\/main>/m, 1]

    raise "#{name}: missing main content area" unless main
    raise "#{name}: menu content was lost" unless main.include?("<p>Menu content</p>")
    if expected.empty?
      raise "#{name}: unexpected content outside navigation" unless main.sub(/<nav\b.*?<\/nav>/m, "").strip.empty?
      next
    end

    raise "#{name}: homepage content was not rendered exactly once" unless main.scan(expected).length == 1
    raise "#{name}: homepage content must precede navigation" unless main.index(expected) < main.index("<nav")
  end
end

puts "Homepage layout checks passed (Markdown, HTML, empty content)."
