# frozen_string_literal: true

require "bundler"
require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/installer"
require "rubygems/package"
require "tmpdir"
require "yaml"

def assert_package(condition, message)
  raise message unless condition
end

def build_consumer(gem_home, version, output_root)
  spec = Gem::Specification.find_by_name("monoholic", "= #{version}")
  installed_root = File.realpath(spec.full_gem_path)
  assert_package(
    installed_root.start_with?("#{File.realpath(gem_home)}/"),
    "Consumer must use the installed package, not the repository theme"
  )
  assert_package(
    Bundler.which("jekyll").nil?,
    "Consumer must not have a Jekyll wrapper on PATH"
  )

  ["", "/blog"].each_with_index do |baseurl, index|
    destination = File.join(output_root, "output-#{index}")
    config_path = File.join(output_root, "config-#{index}.yml")
    config = {
      "source" => Dir.pwd,
      "destination" => destination,
      "theme" => "monoholic",
      "ignore_theme_config" => true,
      "disable_disk_cache" => true,
      "title" => "Packaged theme",
      "lang" => "en-GB",
      "theme_config" => {
        "skip_link_label" => "Skip to main content",
        "site_sections_label" => "Sections & links"
      },
      "url" => "https://example.test",
      "baseurl" => baseurl,
      "future" => true,
      "quiet" => true
    }
    File.write(config_path, YAML.dump(config))
    output, status = Open3.capture2e(
      RbConfig.ruby, Gem.bin_path("bundler", "bundle", Bundler::VERSION),
      "exec", RbConfig.ruby, Gem.bin_path("jekyll", "jekyll"),
      "build", "--config", config_path
    )
    assert_package(
      status.success?, "Packaged consumer CLI build failed:\n#{output}"
    )

    home = File.read(File.join(destination, "index.html"))
    page = File.read(File.join(destination, "about.html"))
    post = File.read(File.join(destination, "2026/01/01/example.html"))
    [home, post].each do |output|
      assert_package(output.include?('<html lang="en-GB">'), "Site language was not inherited")
    end
    assert_package(page.include?('<html lang="en-US">'), "Page language override was ignored")
    assert_package(home.include?("Skip to main content"), "Configured skip-link label missing")
    assert_package(
      home.include?('aria-label="Sections &amp; links"'),
      "Configured navigation label missing or not escaped"
    )
    assert_package(home.include?("<strong>home</strong>"), "Homepage content lost")
    assert_package(page.include?("Page content."), "Page layout failed")
    assert_package(post.include?("Post content."), "Post layout failed")
    assert_package(home.include?('class="site-header"'), "Default layout failed")
    assert_package(home.include?('class="post-list"'), "Post list missing")
    assert_package(
      home.include?("<strong>Packaged theme</strong>"),
      "Menu include did not render Liquid before Markdown"
    )
    assert_package(
      home.include?("href=\"#{baseurl}/about.html\""),
      "Menu include link does not honor baseurl"
    )
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
  puts "Packaged consumer CLI builds passed (root site and /blog project site)."
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
has_erb_dependency = package_spec.runtime_dependencies.any? do |dependency|
  dependency.name == "erb"
end
assert_package(
  has_erb_dependency, "Package must declare ERB as a runtime dependency"
)

# Use the development bundle only to locate installed gems. Adding its
# dependencies to the consumer Gemfile would hide missing runtime dependencies.
dependencies = Bundler.load.specs.reject do |spec|
  %w[monoholic bundler].include?(spec.name)
end
bundle = Gem.bin_path("bundler", "bundle", Bundler::VERSION)
script = File.expand_path(__FILE__)

Dir.mktmpdir("monoholic-consumer-") do |root|
  gem_home = File.join(root, "gems")
  source = File.join(root, "site")
  FileUtils.mkdir_p([
    gem_home, File.join(source, "_data"), File.join(source, "_posts"),
    File.join(source, "_includes", "fragments")
  ])
  Gem::Installer.at(
    artifact, install_dir: gem_home, ignore_dependencies: true,
    wrappers: false, document: []
  ).install

  File.write(
    File.join(source, "Gemfile"),
    "source 'https://rubygems.org'\n" \
    "gem 'monoholic', '= #{package_spec.version}'\n"
  )
  File.write(
    File.join(source, "index.md"), "---\nlayout: home\n---\nWelcome **home**.\n"
  )
  File.write(
    File.join(source, "about.md"), "---\nlayout: page\nlang: en-US\n---\nPage content.\n"
  )
  File.write(
    File.join(source, "_data", "menu.yml"),
    "entries:\n  - title: About\n    content_include: fragments/intro.md\n  - title: Archive\n    post_list: true\n"
  )
  File.write(
    File.join(source, "_includes", "fragments", "intro.md"),
    "**{{ site.title }}**. [About]({{ '/about.html' | relative_url }})\n"
  )
  File.write(
    File.join(source, "_posts", "2026-01-01-example.md"),
    "---\nlayout: post\ntitle: Example\n---\nPost content.\n\n```ruby\nputs 'hello'\n```\n"
  )

  # CI may keep dependencies in vendor/bundle while Bundler itself is installed
  # elsewhere. Both must remain available in the isolated subprocess.
  gem_paths = [
    gem_home, *Gem.path, *dependencies.map(&:base_dir),
    Gem.loaded_specs.fetch("bundler").base_dir
  ].uniq
  environment = {
    "GEM_HOME" => gem_home,
    "GEM_PATH" => gem_paths.join(File::PATH_SEPARATOR),
    "BUNDLE_GEMFILE" => File.join(source, "Gemfile"),
    "BUNDLE_APP_CONFIG" => File.join(source, ".bundle"),
    "BUNDLE_PATH" => nil,
    "BUNDLE_FROZEN" => "false",
    "BUNDLE_DEPLOYMENT" => "false",
    "BUNDLE_DISABLE_SHARED_GEMS" => "false",
    # Reproduce vendored CI installs without global gem executables.
    "PATH" => "",
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
