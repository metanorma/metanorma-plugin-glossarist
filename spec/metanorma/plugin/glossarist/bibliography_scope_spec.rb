# frozen_string_literal: true

RSpec.describe "Bibliography scope" do
  let(:v3_collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v3")
    c
  end

  describe Metanorma::Plugin::Glossarist::BibliographyRenderer do
    it "only renders bibliography entries for the given concepts" do
      concepts = v3_collection.select { |c| c.data.id == "1.1" }
      renderer = described_class.new
      output = renderer.render_all(concepts)
      expect(output).to include("ievtermbank")
      expect(output).not_to include("CGPM26")
    end

    it "includes entries for all given concepts" do
      concepts = v3_collection.to_a
      renderer = described_class.new
      output = renderer.render_all(concepts)
      expect(output).to include("ievtermbank")
      expect(output).to include("CGPM26")
    end

    it "does not include entries from concepts not passed to render_all" do
      concepts = v3_collection.select { |c| c.data.id == "1.2" }
      renderer = described_class.new
      output = renderer.render_all(concepts)
      expect(output).not_to include("ievtermbank")
      expect(output).to include("CGPM26")
    end
  end

  describe Metanorma::Plugin::Glossarist::DatasetPreprocessor do
    let(:preprocessor) { described_class.new }
    let(:document) { Asciidoctor::Document.new }

    it "render_bibliography emits entries only for rendered concepts" do
      reader = Asciidoctor::Reader.new <<~ADOC
        :glossarist-dataset: ds1:./spec/fixtures/dataset-glossarist-v3
        == Section
        glossarist::import[ds1, tag=test-domain]
        glossarist::render_bibliography[ds1]
      ADOC

      result = preprocessor.process(document, reader).source

      bib_lines = result.lines.select { |l| l.include?("[[[") }
      bib_anchors = bib_lines.filter_map { |l| l[/\[\[\[([^,]+)/, 1] }
      expect(bib_anchors).to include("ievtermbank")
      expect(bib_anchors).not_to include("CGPM26")
    end

    it "render_bibliography includes all entries when all concepts rendered" do
      reader = Asciidoctor::Reader.new <<~ADOC
        :glossarist-dataset: ds1:./spec/fixtures/dataset-glossarist-v3
        == Section
        glossarist::import[ds1]
        glossarist::render_bibliography[ds1]
      ADOC

      result = preprocessor.process(document, reader).source

      bib_lines = result.lines.select { |l| l.include?("[[[") }
      bib_anchors = bib_lines.filter_map { |l| l[/\[\[\[([^,]+)/, 1] }
      expect(bib_anchors).to include("ievtermbank")
      expect(bib_anchors).to include("CGPM26")
    end

    it "render_bibliography skips entries already manually defined in document" do
      reader = Asciidoctor::Reader.new <<~ADOC
        :glossarist-dataset: ds1:./spec/fixtures/dataset-glossarist-v3
        == Section
        glossarist::import[ds1]
        [bibliography]
        == Bibliography
        * [[[CGPM26,CGPM Meeting 26]]], _Proceedings of the 26th CGPM_
        glossarist::render_bibliography[ds1]
      ADOC

      result = preprocessor.process(document, reader).source

      bib_lines = result.lines.select { |l| l.include?("[[[") }
      bib_anchors = bib_lines.filter_map { |l| l[/\[\[\[([^,]+)/, 1] }
      expect(bib_anchors).to include("CGPM26")
      cgpm_count = bib_anchors.count("CGPM26")
      expect(cgpm_count).to eq(1)
    end
  end
end
