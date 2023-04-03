require "metanorma/plugin/glossarist/version"
require "metanorma/plugin/glossarist/document"
require "metanorma/plugin/glossarist/dataset_preprocessor"

module Metanorma
  module Plugin
    module Glossarist
      class Error < StandardError; end
      # Your code goes here...
    end
  end

  Asciidoctor::Extensions.register do
    preprocessor Metanorma::Plugin::Glossarist::DatasetPreprocessor
  end
end
