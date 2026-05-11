# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::ConceptSerializer do
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

  describe "#to_h" do
    subject { described_class.new(entity_concept).to_h }

    it "returns a hash with data key" do
      expect(subject).to be_a(Hash)
      expect(subject).to have_key("data")
    end

    it "includes concept id" do
      expect(subject["data"]["id"]).to eq("3.1.1.1")
    end

    it "includes localizations" do
      expect(subject["data"]["localizations"]).to be_a(Hash)
      expect(subject["data"]["localizations"]).to have_key("eng")
    end

    it "includes terms in localization" do
      eng = subject["data"]["localizations"]["eng"]
      expect(eng["data"]["terms"]).to be_a(Array)
      expect(eng["data"]["terms"].length).to be >= 1
    end

    it "includes term designation" do
      first_term = subject["data"]["localizations"]["eng"]["data"]["terms"][0]
      expect(first_term["designation"]).to eq("entity")
    end

    it "includes definition" do
      eng = subject["data"]["localizations"]["eng"]
      expect(eng["data"]["definition"]).to be_a(Array)
      expect(eng["data"]["definition"][0]["content"]).to include("concrete or abstract thing")
    end

    it "includes sources" do
      eng = subject["data"]["localizations"]["eng"]
      expect(eng["data"]["sources"]).to be_a(Array)
    end

    it "includes groups when present" do
      entity_with_group = collection.find { |c| c.data.groups&.include?("foo") }
      if entity_with_group
        hash = described_class.new(entity_with_group).to_h
        expect(hash["data"]["groups"]).to include("foo")
      end
    end
  end
end
