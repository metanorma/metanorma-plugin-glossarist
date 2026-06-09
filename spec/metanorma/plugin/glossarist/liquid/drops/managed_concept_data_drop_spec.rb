# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::ManagedConceptDataDrop do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:concept) { collection.find { |c| c.default_designation == "entity" } }
  let(:drop) { described_class.new(concept.data) }

  describe "#localizations" do
    it "returns a LocalizationCollectionDrop" do
      expect(drop.localizations).to be_a(Metanorma::Plugin::Glossarist::Liquid::LocalizationCollectionDrop)
    end

    it "caches the drop instance" do
      first = drop.localizations
      expect(drop.localizations).to equal(first)
    end
  end

  describe "#identifier" do
    it "returns the concept data id" do
      expect(drop.identifier).to eq(concept.data.id)
    end
  end

  describe "#liquid_method_missing" do
    it "delegates to auto-generated drop for known attributes" do
      result = drop.liquid_method_missing("id")
      expect(result).to eq("3.1.1.1")
    end

    it "returns nil for unknown attributes" do
      result = drop.liquid_method_missing("nonexistent_attribute")
      expect(result).to be_nil
    end
  end
end
