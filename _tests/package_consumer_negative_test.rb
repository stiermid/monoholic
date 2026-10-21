# frozen_string_literal: true

require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

abort "Usage: bundle exec ruby #{$PROGRAM_NAME} PATH_TO_GEM" unless ARGV.length == 1
artifact = File.expand_path(ARGV.first)
consumer_test = File.expand_path("package_consumer_test.rb", __dir__)
cases = {
  "missing stylesheet" => [
    ->(spec) { spec.files.delete("assets/css/style.scss") },
    "Missing or empty assets/css/style.css"
  ],
  "mismatched version" => [
    ->(spec) { spec.version = "0.0.0" }, "Package version differs from source"
  ],
  "unexpected name" => [
    ->(spec) { spec.name = "not-monoholic" }, "Unexpected gem name"
  ]
}

if Gem.ruby_version >= Gem::Version.new("3.4")
  cases["missing ERB runtime dependency"] = [
    ->(spec) do
      spec.dependencies.delete_if { |dependency| dependency.name == "erb" }
    end,
    "cannot load such file -- erb"
  ]
end

cases.each do |name, (mutate, expected_error)|
  Dir.mktmpdir("monoholic-broken-package-") do |root|
    package = Gem::Package.new(artifact)
    package.extract_files(root)
    spec = package.spec
    mutate.call(spec)
    broken_artifact = File.join(root, "broken.gem")
    Dir.chdir(root) { Gem::Package.build(spec, true, false, broken_artifact) }
    output, status = Open3.capture2e(RbConfig.ruby, consumer_test, broken_artifact)
    raise "Accepted #{name}" if status.success?
    unless output.include?(expected_error)
      raise "#{name} failed for the wrong reason:\n#{output}"
    end
  end
end

puts "Invalid package checks passed (#{cases.keys.join(', ')})."
