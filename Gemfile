Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}" }

gem "metanorma-standoc"
gem "pry"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.6"

gemspec

begin
  eval_gemfile("Gemfile.devel")
rescue StandardError
  nil
end
