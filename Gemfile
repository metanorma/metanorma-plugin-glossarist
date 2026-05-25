# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}" }

gem "metanorma", github: "metanorma/metanorma", branch: "main"
gem "metanorma-plugin-lutaml", github: "metanorma/metanorma-plugin-lutaml",
                               branch: "main"
gem "metanorma-standoc", github: "metanorma/metanorma-standoc", branch: "main"
gem "ogc-gml", "~> 1.1"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"

# TODO: remove once glossarist 2.7.0 is released with Citation#label
gem "glossarist", github: "glossarist/glossarist-ruby", branch: "main"

gemspec
