# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::LocalizationCollectionDrop do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:concept) { collection.find { |c| c.default_designation == "entity" } }
  let(:localizations) { concept.data.localizations }
  let(:drop) { described_class.new(localizations) }

  describe "#liquid_method_missing" do
    it "returns a localization drop for valid language code" do
      result = drop.liquid_method_missing("eng")
      expect(result).not_to be_nil
    end

    it "returns nil for unknown language code" do
      result = drop.liquid_method_missing("xxx")
      expect(result).to be_nil
    end
  end

  describe "#size" do
    it "returns the number of localizations" do
      expect(drop.size).to eq(localizations.size)
    end
  end

  describe "#each" do
    it "iterates over localizations" do
      items = []
      drop.each { |i| items << i }
      expect(items.size).to eq(localizations.size)
    end
  end

  describe "#first" do
    it "returns the first localization" do
      expect(drop.first).to eq(localizations.first)
    end
  end

  describe "#last" do
    it "returns the last localization" do
      expect(drop.last).to eq(localizations.last)
    end
  end
end
