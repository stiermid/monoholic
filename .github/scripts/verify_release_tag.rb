# frozen_string_literal: true

require "rubygems"

module ReleaseTag
  def self.verify!(tag, version)
    expected = "v#{version}"
    return if tag == expected

    raise ArgumentError, "Release tag #{tag.inspect} must match gem version #{expected.inspect}."
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby #{$PROGRAM_NAME} TAG" unless ARGV.length == 1
  path = File.expand_path("../../monoholic.gemspec", __dir__)
  spec = Gem::Specification.load(path)
  abort "Could not load #{path}" unless spec

  begin
    ReleaseTag.verify!(ARGV.first, spec.version)
  rescue ArgumentError => error
    abort error.message
  end
  puts "Release tag matches gem version #{spec.version}."
end
