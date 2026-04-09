Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}" }

gem "metanorma-standoc", github: "metanorma/metanorma-standoc"
gem "isodoc", github: "metanorma/isodoc"
gem "metanorma", github: "metanorma/metanorma"

gem "pry"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.6"

gemspec

begin
  eval_gemfile("Gemfile.devel")
rescue StandardError
  nil
end
