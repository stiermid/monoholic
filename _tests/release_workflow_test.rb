# frozen_string_literal: true

require "yaml"

def assert_equal(expected, actual, message)
  return if expected == actual

  raise "#{message}: expected #{expected.inspect}, got #{actual.inspect}"
end

path = File.expand_path("../.github/workflows/gem-push.yml", __dir__)
workflow = YAML.load_file(path)
# Psych parses YAML 1.1, where the unquoted key `on` is a boolean.
events = workflow.fetch("on") { workflow.fetch(true) }
assert_equal(["v*"], events.fetch("push").fetch("tags"), "release tag trigger")
assert_equal(["master"], events.fetch("pull_request").fetch("branches"), "PR trigger")

jobs = workflow.fetch("jobs")
check = jobs.fetch("check")
publish = jobs.fetch("publish")
assert_equal(nil, check["if"], "validation must run for PRs and release tags")
assert_equal(
  ["3.3", "3.4"], check.fetch("strategy").fetch("matrix").fetch("ruby"),
  "validate consumers before and after ERB stopped being a default gem"
)
assert_equal(false, check.fetch("strategy").fetch("fail-fast"), "complete both Ruby checks")
assert_equal(nil, check["continue-on-error"], "Ruby failures must block publishing")
assert_equal({ "contents" => "read" }, check.fetch("permissions"), "validation permissions")
assert_equal(["check"], Array(publish["needs"]), "publishing must depend on validation")
assert_equal(
  "github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')",
  publish.fetch("if"), "publishing must be restricted to tag pushes"
)

steps = check.fetch("steps")
ruby_setup = steps.find { |step| step["uses"] == "ruby/setup-ruby@v1" }
raise "Missing validation Ruby setup" unless ruby_setup
assert_equal(
  "${{ matrix.ruby }}", ruby_setup.fetch("with").fetch("ruby-version"),
  "use the matrix Ruby version"
)
tag_step = steps.find { |step| step["run"].to_s.include?("verify_release_tag.rb") }
raise "Missing release tag validation" unless tag_step
assert_equal(publish.fetch("if"), tag_step.fetch("if"), "tag validation event guard")
assert_equal(
  { "RELEASE_TAG" => "${{ github.ref_name }}" }, tag_step.fetch("env"),
  "pass tag through the environment, not shell interpolation"
)
assert_equal(
  'bundle exec ruby .github/scripts/verify_release_tag.rb "$RELEASE_TAG"',
  tag_step.fetch("run"), "quote the release tag argument"
)
%w[package_consumer_test.rb package_consumer_negative_test.rb].each do |test|
  consumer_step = steps.find { |step| step["run"].to_s.include?("_tests/#{test}") }
  raise "Missing #{test} validation" unless consumer_step
  assert_equal(nil, consumer_step["if"], "#{test} must run on both Rubies")
end

diagnostics = steps.find { |step| step["name"] == "Upload browser failure diagnostics" }
raise "Missing browser failure diagnostics" unless diagnostics
assert_equal(
  "browser-failure-diagnostics-ruby-${{ matrix.ruby }}",
  diagnostics.fetch("with").fetch("name"), "keep matrix failure artifacts distinct"
)

upload = steps.find do |step|
  step["uses"] == "actions/upload-artifact@v4" &&
    step.dig("with", "name") == "validated-gem"
end
raise "Missing validated release artifact" unless upload
assert_equal(
  "#{publish.fetch('if')} && matrix.ruby == '3.3'", upload.fetch("if"),
  "only the Ruby 3.3 tag build uploads the release artifact"
)
assert_equal(
  "error", upload.fetch("with").fetch("if-no-files-found"), "missing artifact must fail"
)
assert_equal(
  true, upload.fetch("with").fetch("overwrite"), "validation reruns must replace the artifact"
)
assert_equal(
  %w[_tests/.release/monoholic.gem _tests/.release/monoholic.gem.sha256],
  upload.fetch("with").fetch("path").split, "release artifact contents"
)
assert_equal(upload, steps.last, "upload only after all validations complete")

publish_steps = publish.fetch("steps")
download = publish_steps.find do |step|
  step["uses"] == "actions/download-artifact@v4"
end
raise "Publisher must download the validated artifact" unless download
assert_equal(
  "validated-gem", download.fetch("with").fetch("name"), "matching artifact names"
)
assert_equal("release", download.fetch("with").fetch("path"), "artifact destination")
raise "Publisher must not rebuild gems" if publish_steps.any? do |step|
  step["run"].to_s.include?("gem build")
end

verify = publish_steps.find do |step|
  step["run"].to_s.include?("sha256sum --check --strict")
end
raise "Publisher must verify the artifact checksum" unless verify
assert_equal(
  "release", verify.fetch("working-directory"), "verify downloaded bytes"
)
assert_equal(
  { "RELEASE_TAG" => "${{ github.ref_name }}" }, verify.fetch("env"),
  "verify artifact release tag"
)
unless verify.fetch("run").include?("Gem::Package.new")
  raise "Publisher must also verify package metadata"
end

pushes = publish_steps.select { |step| step["run"].to_s.include?("gem push") }
assert_equal(2, pushes.length, "both registries publish the validated gem")
pushes.each do |step|
  assert_equal("release", step.fetch("working-directory"), "publish downloaded bytes")
  raise "Unvalidated package wildcard" if step.fetch("run").include?("*.gem")
  unless publish_steps.index(verify) < publish_steps.index(step)
    raise "Publishing before integrity verification"
  end
end

puts "Release workflow guards passed (Ruby matrix, gating, validation, artifact handoff, integrity)."
