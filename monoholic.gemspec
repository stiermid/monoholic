# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "monoholic"
  spec.version       = "1.0.1"
  spec.authors       = ["Agil Mammadov"]
  spec.email         = ["mammadovagil@proton.me"]

  spec.summary       = "Minimal monochrome dark Jekyll theme"
  spec.homepage      = "https://github.com/stiermid/monoholic"
  spec.license       = "GPL-3.0-only"

  spec.files         = `git ls-files -z`.split("\x0").select { |f| f.match(%r!^(assets|_data|_layouts|_includes|_sass|LICENSE|README)!i) }

  spec.add_runtime_dependency "jekyll", "~> 4.4"
  spec.add_runtime_dependency "jekyll-sass-converter", "~> 3.0"
  spec.add_runtime_dependency "jekyll-feed", "~> 0.12"
  spec.add_runtime_dependency "jekyll-seo-tag", "~> 2.8"
end
