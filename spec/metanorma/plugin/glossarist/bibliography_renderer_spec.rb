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

  def bibliography_with(entries)
    yaml = { "bibliography" => entries.map { |e| e.transform_keys(&:to_s) } }.to_yaml
    Glossarist::BibliographyData.from_yaml(yaml)
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

    it "renders xref entries when bibliography is provided" do
      v3_collection = Glossarist::ManagedConceptCollection.new
      v3_collection.load_from_files("./spec/fixtures/dataset-glossarist-v3")
      bibliography = bibliography_with(
        [{ "id" => "ievtermbank", "reference" => "IEV",
           "title" => "IEV: Electropedia" }],
      )
      renderer = described_class.new(bibliography: bibliography)
      output = renderer.render_all(v3_collection.to_a)
      expect(output).to include("[[[ievtermbank")
    end

    it "extracts cross-references from annotations" do
      v3_collection = Glossarist::ManagedConceptCollection.new
      v3_collection.load_from_files("./spec/fixtures/dataset-glossarist-v3")
      concept = v3_collection.find { |c| c.data&.id == "1.1" }

      annotations = concept.localization("eng").data.annotations
      expect(annotations).not_to be_empty,
                                 "V3 annotations failed to parse — check glossarist version"

      bibliography = bibliography_with(
        [{ "id" => "iso_9999", "reference" => "ISO 9999", "title" => "Test" }],
      )
      renderer = described_class.new(bibliography: bibliography)
      output = renderer.render_all([concept])
      expect(output).to include("[[[iso_9999,ISO 9999")
    end

    it "includes title from bibliography in formatted entry" do
      bibliography = bibliography_with(
        [{ "id" => "ISO/TS 14812:2022",
           "reference" => "ISO/TS 14812:2022",
           "title" => "Intelligent Transport Systems" }],
      )
      renderer = described_class.new(bibliography: bibliography)
      entry = renderer.render_entry(entity_concept)
      expect(entry).to include("_Intelligent Transport Systems_")
    end

    it "renders link from bibliography entry when present" do
      bibliography = bibliography_with(
        [{ "id" => "ISO/TS 14812:2022",
           "reference" => "ISO/TS 14812:2022",
           "title" => "Intelligent Transport Systems",
           "link" => "https://www.iso.org/standard.html" }],
      )
      renderer = described_class.new(bibliography: bibliography)
      entry = renderer.render_entry(entity_concept)
      expect(entry).to include("Available at: https://www.iso.org/standard.html")
    end
  end

  describe "with document citations" do
    let(:urn_yaml) do
      <<~YAML
        data:
          language_code: eng
          terms:
          - designation: activity
            normative_status: preferred
            type: expression
          definition:
          - content: represents the activity entity
          sources:
          - origin:
              ref:
                source: urn:iso:std:iso:10303:-2:ed-1:en:tech:Activity_arm:tech:Activity_arm
                id: Activity_arm
                version: '3'
            type: authoritative
        id: urnsrc-eng
      YAML
    end

    def urn_concept(id: "urnsrc", l10n_id: "urnsrc-eng")
      lc = Glossarist::LocalizedConcept.from_yaml(urn_yaml)
      mc_data = Glossarist::ManagedConceptData.from_yaml(
        "id: #{id}\nlocalized_concepts:\n  eng: #{l10n_id}\n",
      )
      mc = Glossarist::ManagedConcept.new(data: mc_data)
      mc.add_localization(lc)
      mc
    end

    def documents
      registry = Metanorma::Plugin::Glossarist::DatasetRegistry.new
      path = File.expand_path("../../../fixtures/document-citation-register",
                              __dir__)
      registry.register(nil, "concepts:#{path}")
      registry.document_citations
    end

    it "renders one entry per parent document, not per concept" do
      renderer = described_class.new(documents: documents)
      entry = renderer.render_all([urn_concept(id: "a", l10n_id: "a-eng"),
                                   urn_concept(id: "b", l10n_id: "b-eng")])
      expect(entry).to eq("* [[[urn_iso_std_iso_10303_-2_ed-1_en,ISO 10303-2]]]")
    end

    it "emits no mangled per-concept URN anchors" do
      renderer = described_class.new(documents: documents)
      entry = renderer.render_all([urn_concept])
      expect(entry).not_to include("tech_Activity_arm")
    end

    it "honours existing anchors for the document bibitem" do
      renderer = described_class.new(
        existing_anchors: ["urn_iso_std_iso_10303_-2_ed-1_en"],
        documents: documents,
      )
      expect(renderer.render_all([urn_concept])).to be_empty
    end

    it "keeps legacy entries for non-URN sources" do
      renderer = described_class.new(documents: documents)
      entry = renderer.render_entry(entity_concept)
      expect(entry).to eq("* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]")
    end
  end
end
