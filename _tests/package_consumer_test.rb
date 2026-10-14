# frozen_string_literal: true

require "bundler"
require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/installer"
require "rubygems/package"
require "tmpdir"

def assert_package(condition, message)
  raise message unless condition
end

def build_consumer(gem_home, version, output_root)
  require "jekyll"

  spec = Gem::Specification.find_by_name("monoholic", "= #{version}")
  installed_root = File.realpath(spec.full_gem_path)
  assert_package(
    installed_root.start_with?("#{File.realpath(gem_home)}/"),
    "Consumer must use the installed package, not the repository theme"
  )

  ["", "/blog"].each_with_index do |baseurl, index|
    destination = File.join(output_root, "output-#{index}")
    config = Jekyll.configuration(
      "config" => [],
      "source" => Dir.pwd,
      "destination" => destination,
      "theme" => "monoholic",
      "ignore_theme_config" => true,
      "disable_disk_cache" => true,
      "title" => "Packaged theme",
      "url" => "https://example.test",
      "baseurl" => baseurl,
      "future" => true,
      "quiet" => true
    )
    site = Jekyll::Site.new(config)
    assert_package(
      File.realpath(site.theme.root) == installed_root, "Incorrect theme root"
    )
    site.process

    home = File.read(File.join(destination, "index.html"))
    page = File.read(File.join(destination, "about.html"))
    post = File.read(File.join(destination, "2026/01/01/example.html"))
    assert_package(home.include?("<strong>home</strong>"), "Homepage content lost")
    assert_package(page.include?("Page content."), "Page layout failed")
    assert_package(post.include?("Post content."), "Post layout failed")
    assert_package(home.include?('class="site-header"'), "Default layout failed")
    assert_package(home.include?('class="post-list"'), "Post list missing")
    assert_package(
      home.include?("href=\"#{baseurl}/2026/01/01/example.html\""),
      "Post link does not honor baseurl"
    )
    assert_package(
      home.include?("href=\"https://example.test#{baseurl}/\""),
      "Canonical URL missing or incorrect"
    )
    assert_package(
      home.include?("src=\"#{baseurl}/assets/js/content-scroll.js\""),
      "Theme script URL does not honor baseurl"
    )

    %w[
      assets/css/style.css assets/js/content-scroll.js assets/favicon.ico
      assets/favicon.svg assets/apple-touch-icon.png feed.xml sitemap.xml robots.txt
    ].each do |path|
      assert_package(
        File.size?(File.join(destination, path)), "Missing or empty #{path}"
      )
    end
    css = File.read(File.join(destination, "assets/css/style.css"))
    assert_package(
      css.include?(":root") && css.include?(".table-scroll"),
      "Theme Sass did not compile"
    )
    feed = File.read(File.join(destination, "feed.xml"))
    assert_package(
      feed.include?("https://example.test#{baseurl}/2026/01/01/example.html"),
      "Feed post URL does not honor baseurl"
    )
  end
  puts "Packaged consumer builds passed (root site and /blog project site)."
end

if ARGV.first == "--consumer"
  abort "Invalid consumer arguments" unless ARGV.length == 4
  build_consumer(*ARGV.drop(1))
  exit
end

abort "Usage: bundle exec ruby #{$PROGRAM_NAME} PATH_TO_GEM" unless ARGV.length == 1
artifact = File.expand_path(ARGV.first)
package_spec = Gem::Package.new(artifact).spec
source_spec = Gem::Specification.load(
  File.expand_path("../monoholic.gemspec", __dir__)
)
assert_package(package_spec.name == "monoholic", "Unexpected gem name")
assert_package(
  package_spec.version == source_spec.version, "Package version differs from source"
)

# Resolve using the already-installed lockfile dependencies, without fetching
# gems or using the repository's PATH source for the theme under test.
dependencies = Bundler.load.specs.reject do |spec|
  %w[monoholic bundler].include?(spec.name)
end
bundle = Gem.bin_path("bundler", "bundle", Bundler::VERSION)
script = File.expand_path(__FILE__)

Dir.mktmpdir("monoholic-consumer-") do |root|
  gem_home = File.join(root, "gems")
  source = File.join(root, "site")
  FileUtils.mkdir_p([
    gem_home, File.join(source, "_data"), File.join(source, "_posts")
  ])
  Gem::Installer.at(
    artifact, install_dir: gem_home, ignore_dependencies: true,
    wrappers: false, document: []
  ).install

  gemfile = [
    "source 'https://rubygems.org'", "gem 'monoholic', '= #{package_spec.version}'"
  ]
  dependencies.each { |spec| gemfile << "gem '#{spec.name}', '= #{spec.version}'" }
  File.write(File.join(source, "Gemfile"), "#{gemfile.join("\n")}\n")
  File.write(
    File.join(source, "index.md"), "---\nlayout: home\n---\nWelcome **home**.\n"
  )
  File.write(
    File.join(source, "about.md"), "---\nlayout: page\n---\nPage content.\n"
  )
  File.write(
    File.join(source, "_data", "menu.yml"),
    "entries:\n  - title: Archive\n    post_list: true\n"
  )
  File.write(
    File.join(source, "_posts", "2026-01-01-example.md"),
    "---\nlayout: post\ntitle: Example\n---\nPost content.\n\n```ruby\nputs 'hello'\n```\n"
  )

  gem_paths = [gem_home, *Gem.path, *dependencies.map(&:base_dir)].uniq
  environment = {
    "GEM_HOME" => gem_home,
    "GEM_PATH" => gem_paths.join(File::PATH_SEPARATOR),
    "BUNDLE_GEMFILE" => File.join(source, "Gemfile"),
    "BUNDLE_APP_CONFIG" => File.join(source, ".bundle"),
    "BUNDLE_PATH" => nil,
    "BUNDLE_FROZEN" => "false",
    "BUNDLE_DEPLOYMENT" => "false",
    "BUNDLE_DISABLE_SHARED_GEMS" => "false",
    "RUBYOPT" => nil
  }
  Bundler.with_unbundled_env do
    commands = [
      [RbConfig.ruby, bundle, "lock", "--local"],
      [
        RbConfig.ruby, "-rbundler/setup", script, "--consumer",
        gem_home, package_spec.version.to_s, root
      ]
    ]
    commands.each do |command|
      output, status = Open3.capture2e(environment, *command, chdir: source)
      assert_package(status.success?, "Packaged consumer check failed:\n#{output}")
      puts output unless output.strip.empty?
    end
  end
end
