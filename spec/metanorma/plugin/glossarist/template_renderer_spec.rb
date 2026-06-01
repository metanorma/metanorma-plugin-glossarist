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
  end
end
