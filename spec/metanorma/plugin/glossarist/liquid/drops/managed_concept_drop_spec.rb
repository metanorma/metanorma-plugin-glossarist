# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::ManagedConceptDrop do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:concept) { collection.find { |c| c.default_designation == "entity" } }
  let(:drop) { described_class.new(concept) }

  describe "#data" do
    it "returns a drop wrapping concept data with localizations" do
      data = drop.data
      expect(data).to be_a(Metanorma::Plugin::Glossarist::Liquid::ManagedConceptDataDrop)
      expect(data.localizations).to be_a(Metanorma::Plugin::Glossarist::Liquid::LocalizationCollectionDrop)
    end

    it "exposes localizations with bracket access returning a drop" do
      l10n = drop.data.localizations["eng"]
      expect(l10n).to be_a(Liquid::Drop)
      expect(l10n.data.terms[0].designation).to eq("entity")
    end
  end

  describe "#schema_version" do
    it "returns the schema version from the concept" do
      expect(drop.schema_version).to eq(concept.schema_version)
    end
  end

  describe "#default_designation" do
    it "returns the default designation" do
      expect(drop.default_designation).to eq("entity")
    end
  end

  describe "#identifier" do
    it "returns the identifier or nil" do
      expect(drop.identifier).to eq(concept.identifier)
    end
  end

  describe "#uuid" do
    it "returns the uuid" do
      expect(drop.uuid).to eq(concept.uuid)
    end
  end

  describe "#liquid_method_missing" do
    it "returns a localization drop for valid language code" do
      result = drop.liquid_method_missing("eng")
      expect(result).to be_a(Liquid::Drop)
    end

    it "returns nil for unknown language code" do
      result = drop.liquid_method_missing("xxx")
      expect(result).to be_nil
    end
  end
end
