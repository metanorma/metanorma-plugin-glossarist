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

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "asciidoctor", "~> 2.0.0"
  spec.add_dependency "glossarist", "~> 2.0"
  spec.add_dependency "liquid", "~> 5"

  spec.add_development_dependency "metanorma-standoc"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
