require "bundler/setup"
require "metanorma-plugin-glossarist"

# Register GlossaristProcessor as first preprocessor in line in order
# to test properly with metanorma-standoc
Asciidoctor::Extensions.register do
  preprocessor Metanorma::Plugin::Glossarist::DatasetPreprocessor
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
