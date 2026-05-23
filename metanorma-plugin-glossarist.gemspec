# frozen_string_literal: true

require_relative "lib/metanorma/plugin/glossarist/version"

Gem::Specification.new do |spec|
  spec.name          = "metanorma-plugin-glossarist"
  spec.version       = Metanorma::Plugin::Glossarist::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "Metanorma plugin for glossarist"
  spec.description   = "Metanorma plugin for glossarist"

  spec.homepage      = "https://github.com/metanorma/metanorma-plugin-glossarist"
  spec.license       = "BSD-2-Clause"

  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.1.0"

  spec.add_dependency "asciidoctor"
  spec.add_dependency "glossarist", "~> 2.6"
  spec.add_dependency "liquid"
  spec.add_dependency "metanorma-utils"
  spec.metadata["rubygems_mfa_required"] = "true"
end
