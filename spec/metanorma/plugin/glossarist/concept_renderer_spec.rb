# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::ConceptRenderer do
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
  let(:biological_entity) do
    collection.find do |c|
      c.default_designation == "biological entity"
    end
  end

  describe "#render" do
    it "renders entity concept with all sections" do
      renderer = described_class.new(entity_concept, depth: 2)
      output = renderer.render

      expect(output).to include("[[3.1.1.1]]")
      expect(output).to include("=== entity")
      expect(output).to include("admitted:[E]")
      expect(output).to include("concrete or abstract thing that exists")
      expect(output).to include("[example]")
      expect(output).to include("[.source]")
      expect(output).to include("<<ISO_TS_14812_2022,3.1.1.1>>")
    end

    it "renders material entity with notes" do
      renderer = described_class.new(material_entity, depth: 2)
      output = renderer.render

      expect(output).to include("[[3.1.1.3]]")
      expect(output).to include("=== material entity")
      expect(output).to include("[NOTE]")
      expect(output).to include("====")
      expect(output).to include("important for ontology purposes")
      expect(output).to include("[.source]")
    end

    it "renders biological entity without alt terms or examples" do
      renderer = described_class.new(biological_entity, depth: 2)
      output = renderer.render

      expect(output).to include("[[3.1.1.5]]")
      expect(output).to include("=== biological entity")
      expect(output).not_to include("admitted:[")
      expect(output).not_to include("[example]")
      expect(output).not_to include("[NOTE]")
    end

    it "respects depth for heading level" do
      renderer = described_class.new(entity_concept, depth: 3)
      expect(renderer.render).to include("==== entity")
    end

    it "applies anchor prefix" do
      renderer = described_class.new(entity_concept, depth: 2,
                                                     anchor_prefix: "prefix-")
      expect(renderer.render).to include("[[prefix-3.1.1.1]]")
    end

    it "uses default depth of 2 when not specified" do
      renderer = described_class.new(entity_concept, depth: 2)
      expect(renderer.render).to include("=== entity")
    end
  end
end
