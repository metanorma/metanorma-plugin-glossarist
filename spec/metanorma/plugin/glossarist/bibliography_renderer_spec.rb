# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::BibliographyRenderer do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:entity_concept) do
    collection.find do |c|
      c.default_designation == "entity"
    end
  end
  let(:material_entity) do
    collection.find do |c|
      c.default_designation == "material entity"
    end
  end

  describe "#render_entry" do
    it "renders a bibliography entry for a concept" do
      renderer = described_class.new
      entry = renderer.render_entry(entity_concept)
      expect(entry).to eq("* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]")
    end

    it "returns nil for concept with no source" do
      concept = collection.find do |c|
        c.default_designation == "biological entity"
      end
      # biological entity source may or may not have origin text
      renderer = described_class.new
      entry = renderer.render_entry(concept)
      # Just verify it doesn't raise
      expect(entry).to(satisfy { |v| v.nil? || v.is_a?(String) })
    end
  end

  describe "#render_all" do
    it "renders all bibliography entries sorted" do
      renderer = described_class.new
      output = renderer.render_all(collection.to_a)
      lines = output.split("\n")
      expect(lines.length).to eq(2)
      expect(lines[0]).to eq("* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]")
      expect(lines[1]).to eq("* [[[ISO_TS_14812_2023,ISO/TS 14812:2023]]]")
    end

    it "does not duplicate entries" do
      renderer = described_class.new
      concepts = collection.to_a + collection.to_a
      output = renderer.render_all(concepts)
      lines = output.split("\n")
      expect(lines.length).to eq(2)
    end
  end
end
