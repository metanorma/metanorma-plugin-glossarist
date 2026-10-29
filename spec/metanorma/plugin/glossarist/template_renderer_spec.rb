# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::TemplateRenderer do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:concepts) { collection.to_a }
  let(:renderer) { described_class.new(file_system: nil, lang: "eng") }

  describe "#render_concept" do
    let(:concept) { collection.find { |c| c.default_designation == "entity" } }

    it "renders a single concept with heading" do
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to include("=== entity")
    end

    it "respects depth for heading level" do
      result = renderer.render_concept(concept, depth: 3)
      expect(result).to include("==== entity")
    end

    it "includes definition content" do
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to include("concrete or abstract thing")
    end

    it "includes formatted source reference" do
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to include("<<ISO_TS_14812_2022")
    end

    it "returns a string" do
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to be_a(String)
    end

    it "includes alt terms" do
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to include("admitted:[E]")
    end

    it "builds anchor with prefix when provided" do
      concept = collection.find { |c| c.default_designation == "entity" }
      renderer = described_class.new(file_system: nil, lang: "eng")
      result = renderer.render_concept(concept, depth: 2,
                                                anchor_prefix: "prefix-")
      expect(result).to include("[[prefix-")
    end

    it "renders anchor bookmark for concept" do
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to match(/\[\[.*\]\]/)
    end
  end

  describe "#render_concepts" do
    it "renders all concepts in collection" do
      result = renderer.render_concepts(concepts, depth: 2)
      expect(result).to be_a(String)
      expect(result).to include("entity")
    end

    it "returns non-empty output for non-empty collection" do
      result = renderer.render_concepts(concepts, depth: 2)
      expect(result).not_to be_empty
    end

    it "normalizes excessive newlines" do
      result = renderer.render_concepts(concepts, depth: 2)
      expect(result).not_to match(/\n{3,}/)
    end

    it "builds parent-child tree for v3 concepts with broader/narrower" do
      v3_collection = Glossarist::ManagedConceptCollection.new
      v3_collection.load_from_files("./spec/fixtures/dataset-glossarist-v3")
      v3_renderer = described_class.new(file_system: nil, lang: "eng")

      result = v3_renderer.render_concepts(v3_collection.to_a, depth: 2)
      parent_idx = result.index("parent concept")
      child_idx = result.index("child concept")
      expect(parent_idx).to be < child_idx
      expect(result).to match(/=== parent concept.*==== child concept/m)
    end

    it "renders nested examples inside notes (VIM 1993)" do
      yaml = <<~YAML
        data:
          language_code: eng
          terms:
          - designation: nested example concept
            normative_status: preferred
            type: expression
          definition:
          - content: top-level definition
          notes:
          - content: outer note
            examples:
            - content: inner example 1
            - content: inner example 2
        id: nest-eng
      YAML
      lc = Glossarist::LocalizedConcept.from_yaml(yaml)
      mc_data = Glossarist::ManagedConceptData.from_yaml(
        "id: nest\nlocalized_concepts:\n  eng: nest-eng\n",
      )
      mc = Glossarist::ManagedConcept.new(data: mc_data)
      mc.add_localization(lc)

      result = renderer.render_concept(mc, depth: 2)
      expect(result).to include("outer note")
      expect(result).to include("inner example 1")
      expect(result).to include("inner example 2")
      note_idx = result.index("outer note")
      ex1_idx = result.index("inner example 1")
      expect(ex1_idx).to be > note_idx
    end
  end

  describe "concept sources" do
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

    def urn_concept
      lc = Glossarist::LocalizedConcept.from_yaml(urn_yaml)
      mc_data = Glossarist::ManagedConceptData.from_yaml(
        "id: urnsrc\nlocalized_concepts:\n  eng: urnsrc-eng\n",
      )
      mc = Glossarist::ManagedConcept.new(data: mc_data)
      mc.add_localization(lc)
      mc
    end

    def citation_registry
      registry = Metanorma::Plugin::Glossarist::DatasetRegistry.new
      path = File.expand_path("../../../fixtures/document-citation-register",
                              __dir__)
      registry.register(nil, "concepts:#{path}")
      registry
    end

    it "renders a URN source as a document-citation xref with locality" do
      renderer = described_class.new(
        file_system: nil,
        lang: "eng",
        document_citations: citation_registry.document_citations,
      )
      result = renderer.render_concept(urn_concept, depth: 2)
      expect(result).to include("[.source]")
      expect(result)
        .to include("<<urn_iso_std_iso_10303_-2_ed-1_en," \
                    "locality:tech=Activity_arm>>")
    end

    it "keeps the legacy xref for URN sources without a resolver" do
      result = renderer.render_concept(urn_concept, depth: 2)
      expect(result).to include("[.source]")
      expect(result).to include(
        "<<urn_iso_std_iso_10303_-2_ed-1_en_tech_Activity_arm_" \
        "tech_Activity_arm_Activity_arm>>",
      )
    end

    it "keeps the legacy xref for non-URN sources with a resolver" do
      renderer = described_class.new(
        file_system: nil,
        lang: "eng",
        document_citations: citation_registry.document_citations,
      )
      concept = collection.find { |c| c.default_designation == "entity" }
      result = renderer.render_concept(concept, depth: 2)
      expect(result).to include("<<ISO_TS_14812_2022")
    end
  end
end
