# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::ConceptPathResolver do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:concept) { collection.find { |c| c.default_designation == "entity" } }
  let(:resolver) { described_class.new }

  describe "#resolve" do
    it "resolves default_designation" do
      expect(resolver.resolve(concept, "default_designation")).to eq("entity")
    end

    it "resolves schema_version" do
      result = resolver.resolve(concept, "schema_version")
      expect(result).to be_a(String)
    end

    it "resolves data.id" do
      expect(resolver.resolve(concept, "data.id")).to eq("3.1.1.1")
    end

    it "resolves data.domains" do
      result = resolver.resolve(concept, "data.domains")
      expect(result).to be_a(String)
    end

    it "resolves deeply nested path with language code" do
      result = resolver.resolve(concept,
                                "data.localizations['eng'].data.terms[0].designation")
      expect(result).to eq("entity")
    end

    it "resolves definition content" do
      result = resolver.resolve(concept,
                                "data.localizations['eng'].data.definition[0].content")
      expect(result).to include("concrete or abstract thing")
    end

    it "resolves source origin text" do
      result = resolver.resolve(concept,
                                "data.localizations['eng'].data.sources[0].origin.text")
      expect(result).to eq("ISO/TS 14812:2022")
    end

    it "returns empty string for nil path result" do
      result = resolver.resolve(concept,
                                "data.localizations['xxx'].data.terms[0].designation")
      expect(result).to eq("")
    end

    it "returns string representation for non-string values" do
      result = resolver.resolve(concept, "data.identifier")
      expect(result).to eq("3.1.1.1")
    end

    it "returns empty string for unknown root key" do
      result = resolver.resolve(concept, "nonexistent")
      expect(result).to eq("")
    end

    it "resolves domains via data" do
      result = resolver.resolve(concept, "data.domains")
      expect(result).to be_a(String)
    end
  end
end
