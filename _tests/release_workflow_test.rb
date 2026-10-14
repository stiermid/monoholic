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
assert_equal({ "contents" => "read" }, check.fetch("permissions"), "validation permissions")
assert_equal(["check"], Array(publish["needs"]), "publishing must depend on validation")
assert_equal(
  "github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')",
  publish.fetch("if"), "publishing must be restricted to tag pushes"
)

puts "Release workflow guards passed (triggers, dependency, permissions)."
