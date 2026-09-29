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

# spec_helper renders through the metanorma :standoc backend
# (Asciidoctor.convert with backend: :standoc), which only
# metanorma-standoc registers — a test-time need. The released gem
# requires none of it: lib/ needs asciidoctor, glossarist, liquid and
# metanorma-utils. The release workflow bundles with `without 'test'`,
# which excludes exactly this group, and `bundle exec rake release`
# keeps working because the Rakefile loads only bundler/gem_tasks
# and rspec.
group :test do
  gem "metanorma-standoc"
end
