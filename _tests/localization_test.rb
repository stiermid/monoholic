# frozen_string_literal: true

require "jekyll"
require "rexml/document"
require "tmpdir"

def assert_equal(expected, actual, message)
  return if expected == actual

  raise "#{message}: expected #{expected.inspect}, got #{actual.inspect}"
end

def opening_element(output, name)
  tag = output[/<#{name}\b[^>]*>/]
  raise "Missing #{name} element" unless tag

  REXML::Document.new(tag.sub(/>\z/, "/>")).root
end

def render_page(site, name, layout, lang = nil)
  page = Jekyll::PageWithoutAFile.new(site, site.source, "", name)
  page.data.merge!(
    "layout" => layout, "title" => "Localization test",
    "date" => Time.utc(2026, 1, 1), "lang" => lang
  )
  page.content = "<p>Page content.</p>"
  Jekyll::Renderer.new(site, page).run
end

Dir.mktmpdir("monoholic-localization-") do |source|
  config = Jekyll.configuration(
    "config" => [], "source" => source,
    "destination" => File.join(source, "_site"),
    "theme" => "monoholic", "ignore_theme_config" => true,
    "safe" => ENV["JEKYLL_SAFE"] == "1",
    "whitelist" => %w[jekyll-feed jekyll-seo-tag jekyll-sitemap],
    "disable_disk_cache" => true, "title" => "Localization test", "quiet" => true
  )
  site = Jekyll::Site.new(config)
  site.read
  site.data["menu"] = { "entries" => [] }

  languages = [
    [nil, nil, "en"],
    ["de", nil, "de"],
    ["de", "fr-CA", "fr-CA"],
    [nil, "zh-Hant-TW", "zh-Hant-TW"],
    ["en-GB", "sr-Latn-RS", "sr-Latn-RS"],
    ["de", "", "de"],
    ["de", false, "de"],
    ["de", " \t ", "de"],
    ["", nil, "en"],
    [false, nil, "en"],
    [" \n ", nil, "en"],
    ["  de  ", " fr-CA ", "fr-CA"],
    ["  de  ", nil, "de"],
    [nil, 'en" data-injected="true', 'en" data-injected="true'],
    ['de" data-injected="true', nil, 'de" data-injected="true']
  ]
  %w[default home page post].each do |layout|
    languages.each_with_index do |(site_lang, page_lang, expected), index|
      site.config["lang"] = site_lang
      output = render_page(site, "#{layout}-language-#{index}.html", layout, page_lang)
      assert_equal(true, output.start_with?("<!doctype html>"), "document starts with its doctype")
      html = opening_element(output, "html")
      assert_equal(expected, html.attributes["lang"], "#{layout}: language case #{index}")
      assert_equal(["lang"], html.attributes.keys, "language must not inject HTML attributes")
    end
  end

  labels = [
    [nil, "Skip to content", "Site sections"],
    [{}, "Skip to content", "Site sections"],
    [
      { "skip_link_label" => nil, "site_sections_label" => nil },
      "Skip to content", "Site sections"
    ],
    [
      { "skip_link_label" => false, "site_sections_label" => false },
      "Skip to content", "Site sections"
    ],
    [
      { "skip_link_label" => "", "site_sections_label" => "" },
      "Skip to content", "Site sections"
    ],
    [
      { "skip_link_label" => " \t ", "site_sections_label" => " \n " },
      "Skip to content", "Site sections"
    ],
    [
      { "skip_link_label" => "Zum Inhalt", "site_sections_label" => "Seitenbereiche" },
      "Zum Inhalt", "Seitenbereiche"
    ],
    [
      {
        "skip_link_label" => " Aller au contenu ",
        "site_sections_label" => " Rubriques du site "
      },
      "Aller au contenu", "Rubriques du site"
    ],
    [
      { "skip_link_label" => "本文へ", "site_sections_label" => "サイトのセクション" },
      "本文へ", "サイトのセクション"
    ],
    [
      {
        "skip_link_label" => 'Go to <main> & "content"',
        "site_sections_label" => 'Sections & "links" <script>'
      },
      'Go to <main> & "content"', 'Sections & "links" <script>'
    ]
  ]
  labels.each_with_index do |(settings, skip_label, sections_label), index|
    site.config["lang"] = "en"
    site.config["theme_config"] = settings
    output = render_page(site, "labels-#{index}.html", "home")
    skip_markup = output[/<a\b[^>]*class="skip-link"[^>]*>.*?<\/a>/m]
    raise "Missing skip link" unless skip_markup

    skip = REXML::Document.new(skip_markup).root
    assert_equal(skip_label, skip.texts.map(&:value).join.strip, "skip-link label case #{index}")
    assert_equal(0, skip.elements.size, "skip-link labels must be text, not HTML")
    assert_equal("#main", skip.attributes["href"], "translation preserves skip-link destination")
    assert_equal(true, output.include?('<main id="main"'), "skip-link destination still exists")
    nav = opening_element(output, "nav")
    assert_equal(sections_label, nav.attributes["aria-label"], "navigation label case #{index}")
    assert_equal(["aria-label"], nav.attributes.keys, "navigation label must not inject HTML attributes")
  end

  mode = site.safe ? "safe mode" : "normal mode"
  puts "Localization checks passed (#{languages.length} language cases across 4 layouts, #{labels.length} label cases, #{mode})."
end
