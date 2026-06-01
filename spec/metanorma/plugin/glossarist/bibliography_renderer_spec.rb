# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::BibliographyRenderer do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:entity_concept) do
    collection.find { |c| c.default_designation == "entity" }
  end

  let(:material_entity) do
    collection.find { |c| c.default_designation == "material entity" }
  end

  describe "#render_entry" do
    it "renders bibliography entries from concept sources" do
      renderer = described_class.new
      entry = renderer.render_entry(entity_concept)
      expect(entry).to eq("* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]")
    end

    it "renders all sources for a concept with multiple sources" do
      renderer = described_class.new
      entry = renderer.render_entry(material_entity)
      lines = entry.split("\n")
      expect(lines).to include(
        "* [[[ISO_11179-1,ISO 11179-1]]]",
      )
      expect(lines).to include(
        "* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]",
      )
    end

    it "returns sorted entries for a single concept" do
      renderer = described_class.new
      entry = renderer.render_entry(material_entity)
      expect(entry).to eq(<<~OUTPUT.strip)
        * [[[ISO_11179-1,ISO 11179-1]]]
        * [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]
      OUTPUT
    end

    it "returns nil for concept with no localization" do
      concept = collection.find do |c|
        c.default_designation == "entity"
      end
      renderer = described_class.new
      expect(renderer.render_entry(concept, lang: "xxx")).to be_nil
    end

    it "deduplicates entries by anchor" do
      renderer = described_class.new
      entry = renderer.render_entry(material_entity)
      anchors = entry.scan(/\[\[\[([^\],]+)/).map(&:first)
      expect(anchors.uniq).to eq(anchors)
    end

    it "warns about unresolved xrefs in content" do
      renderer = described_class.new
      # material entity note has <<ISO_11179_1>> which IS a source — no warning
      expect { renderer.render_entry(material_entity) }.not_to output.to_stderr
    end

    it "renders IEV termbank entry with proper format" do
      concept = entity_concept
      l10n = concept.localization("eng")
      source = l10n.data.sources.sources.first
      source.origin.text = "ievtermbank"

      renderer = described_class.new
      entry = renderer.render_entry(concept)
      expect(entry).to eq("* [[[ievtermbank,IEV]]], _IEV: Electropedia_")
    end

    it "skips entries whose anchors are already in existing_anchors" do
      renderer = described_class.new(existing_anchors: ["ISO_TS_14812_2022"])
      entry = renderer.render_entry(entity_concept)
      expect(entry).to be_nil
    end

    it "skips IEV entry when ievtermbank is in existing_anchors" do
      concept = entity_concept
      l10n = concept.localization("eng")
      source = l10n.data.sources.sources.first
      source.origin.text = "ievtermbank"

      renderer = described_class.new(existing_anchors: ["ievtermbank"])
      entry = renderer.render_entry(concept)
      expect(entry).to be_nil
    end

    it "allows entries whose anchors are not in existing_anchors" do
      renderer = described_class.new(existing_anchors: ["something_else"])
      entry = renderer.render_entry(entity_concept)
      expect(entry).to eq("* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]")
    end
  end

  describe "#render_all" do
    it "renders all entries sorted from all concept sources" do
      renderer = described_class.new
      output = renderer.render_all(collection.to_a)
      lines = output.split("\n")
      expect(lines).to eq(
        [
          "* [[[ISO_11179-1,ISO 11179-1]]]",
          "* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]",
          "* [[[ISO_TS_14812_2023,ISO/TS 14812:2023]]]",
        ],
      )
    end

    it "does not duplicate entries across concepts" do
      renderer = described_class.new
      concepts = collection.to_a + collection.to_a
      output = renderer.render_all(concepts)
      lines = output.split("\n")
      expect(lines.uniq).to eq(lines)
    end
  end
end
