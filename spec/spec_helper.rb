# frozen_string_literal: true

require "bundler/setup"
require "asciidoctor"
require "metanorma-plugin-glossarist"
require "metanorma-standoc"
require "xml-c14n"
require "canon"

Canon::Config.configure do |config|
  config.xml.match.profile = :metanorma
  config.xml.match.options = { comments: :ignore }
  config.xml.diff.algorithm = :semantic
  config.xml.diff.max_node_count = 50_000
end

Asciidoctor::Extensions.register do
  preprocessor Metanorma::Plugin::Glossarist::DatasetPreprocessor
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def strip_guid(xml)
  xml
    .gsub(%r{ id="_[^"]+"}, ' id="_"')
    .gsub(%r{ target="_[^"]+"}, ' target="_"')
    .gsub(%r{<fetched>[^<]+</fetched>}, "<fetched/>")
    .gsub(%r{ schema-version="[^"]+"}, "")
end

def xml_string_content(xml)
  strip_guid(Xml::C14n.format(Nokogiri::XML(xml).to_s))
end

def metanorma_convert(input)
  Asciidoctor.convert(input, backend: :standoc, header_footer: true,
                             agree_to_terms: true, to_file: false, safe: :safe,
                             attributes: ["nodoc", "stem", "xrefstyle=short",
                                          "docfile=test.adoc",
                                          "output_dir="])
end

def metanorma_process(input)
  metanorma_convert(input)
end
