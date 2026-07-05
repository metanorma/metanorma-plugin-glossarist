# frozen_string_literal: true

source "https://rubygems.org"

gem "ogc-gml", "~> 1.1"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"

gemspec

# metanorma / metanorma-standoc / metanorma-plugin-lutaml are needed by
# spec_helper.rb at test time, but live in the default group (not :test)
# so the release workflow's `bundle install --without development test`
# still installs them. Bundler otherwise fails `bundle exec rake release`
# with GemNotFound when the resolver walks the Gemfile.
gem "metanorma"
gem "metanorma-plugin-lutaml"
gem "metanorma-standoc"
