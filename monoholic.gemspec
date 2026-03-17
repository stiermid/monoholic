# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "monoholic"
  spec.version       = "0.1.0"
  spec.authors       = ["Agil Mammadov"]
  spec.email         = ["mammadovagil@tutamail.com"]

  spec.summary       = "TODO: Write a short summary, because Rubygems requires one."
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").select { |f| f.match(%r!^(assets|_data|_layouts|_includes|_sass|LICENSE|README|_config\.yml)!i) }

  spec.add_runtime_dependency "jekyll", "~> 4.4"
  spec.add_runtime_dependency "erb"
  spec.add_runtime_dependency "webrick"
  spec.add_runtime_dependency "jekyll-feed", "~> 0.12"
  spec.add_runtime_dependency "jekyll-seo-tag", "~> 2.8"
end
