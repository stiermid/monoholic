# frozen_string_literal: true

require "open3"
require "rbconfig"
require_relative "../.github/scripts/verify_release_tag"

ReleaseTag.verify!("v1.2.0", Gem::Version.new("1.2.0"))
ReleaseTag.verify!("v2.0.0.pre1", Gem::Version.new("2.0.0.pre1"))

[nil, "", "1.2.0", "v1.1.0", "v1.3.0", "refs/tags/v1.2.0", "v1.2.0; exit 0"].each do |tag|
  rejected = false
  begin
    ReleaseTag.verify!(tag, Gem::Version.new("1.2.0"))
  rescue ArgumentError
    rejected = true
  end
  raise "Accepted invalid release tag #{tag.inspect}" unless rejected
end

root = File.expand_path("..", __dir__)
script = File.join(root, ".github", "scripts", "verify_release_tag.rb")
version = Gem::Specification.load(File.join(root, "monoholic.gemspec")).version
output, status = Open3.capture2e(RbConfig.ruby, script, "v#{version}")
raise "Matching release tag failed: #{output}" unless status.success?

[["v0.0.0"], [], ["v#{version}", "extra"]].each do |arguments|
  output, status = Open3.capture2e(RbConfig.ruby, script, *arguments)
  raise "Invalid CLI arguments succeeded: #{arguments.inspect}" if status.success?
  raise "Missing validation error" if output.strip.empty?
end

puts "Release tag checks passed (matching, mismatched, missing, malformed, prerelease)."
