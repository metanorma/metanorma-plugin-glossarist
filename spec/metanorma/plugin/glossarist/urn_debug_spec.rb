# frozen_string_literal: true

RSpec.describe "debug urn emission" do
  it "shows the emitted adoc" do
    input = <<~TEXT
      = Document title
      Author
      :nodoc:
      :novalid:
      :no-isobib:
      :imagesdir: spec/assets
      :glossarist-dataset: concepts:./spec/fixtures/dataset-no-register

      == Terms

      glossarist::import_sections[concepts, sort_by=term]
    TEXT
    FileUtils.rm_f("test.adoc.glossarist.log.txt")
    metanorma_convert(input)
    log = File.read("test.adoc.glossarist.log.txt")
    line = log.lines.find { |l| l.include?("concept 2") || l.include?("a.concept2") }
    File.write("/tmp/urn-emitted.txt", "LINE: #{line.inspect}\nRAW: #{log.include?('a.concept2')}\n")
  end
end
