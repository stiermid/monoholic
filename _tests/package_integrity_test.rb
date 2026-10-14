# frozen_string_literal: true

require "fileutils"
require "open3"
require "rubygems/package"
require "tmpdir"
require "yaml"

abort "Usage: bundle exec ruby #{$PROGRAM_NAME} GEM CHECKSUM" unless ARGV.length == 2
artifact, manifest = ARGV.map { |path| File.expand_path(path) }
workflow_path = File.expand_path("../.github/workflows/gem-push.yml", __dir__)
workflow = YAML.load_file(workflow_path)
verify = workflow.fetch("jobs").fetch("publish").fetch("steps").find do |step|
  step["name"] == "Verify validated package"
end
raise "Missing publisher verification step" unless verify
# Exercise the actual publisher recipe, without running either registry push.
command = [
  "bash", "--noprofile", "--norc", "-e", "-o", "pipefail", "-c", verify.fetch("run")
]
environment = {
  "RELEASE_TAG" => "v#{Gem::Package.new(artifact).spec.version}",
  "RUBYOPT" => nil,
  "BUNDLE_GEMFILE" => nil
}

Dir.mktmpdir("monoholic-integrity-") do |root|
  package = File.join(root, "monoholic.gem")
  checksum = File.join(root, "monoholic.gem.sha256")
  FileUtils.cp(artifact, package)
  FileUtils.cp(manifest, checksum)
  output, status = Open3.capture2e(environment, *command, chdir: root)
  raise "Valid package checksum failed:\n#{output}" unless status.success?

  wrong_tag = environment.merge(
    "RELEASE_TAG" => "#{environment.fetch("RELEASE_TAG")}.wrong"
  )
  output, status = Open3.capture2e(wrong_tag, *command, chdir: root)
  raise "Mismatched artifact tag accepted" if status.success?
  unless output.include?("release tag")
    raise "Tag mismatch failed for the wrong reason:\n#{output}"
  end

  File.open(package, "ab") { |file| file.write("tampered") }
  _, status = Open3.capture2e(environment, *command, chdir: root)
  raise "Tampered package accepted" if status.success?

  File.unlink(package)
  _, status = Open3.capture2e(environment, *command, chdir: root)
  raise "Missing package accepted" if status.success?

  FileUtils.cp(artifact, package)
  File.write(checksum, "invalid checksum\n")
  _, status = Open3.capture2e(environment, *command, chdir: root)
  raise "Malformed checksum accepted" if status.success?

  File.unlink(checksum)
  _, status = Open3.capture2e(environment, *command, chdir: root)
  raise "Missing checksum accepted" if status.success?
end

puts "Publisher verification checks passed (valid, tag mismatch, tampered, missing, malformed)."
