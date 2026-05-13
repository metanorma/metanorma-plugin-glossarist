# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::ConceptFilter do
  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files("./spec/fixtures/dataset-glossarist-v2")
    c
  end

  let(:all_concepts) { collection.to_a }

  describe "#apply" do
    it "returns all concepts with no filters" do
      filter = described_class.new({})
      result = filter.apply(all_concepts)
      expect(result.length).to eq(all_concepts.length)
    end

    describe "lang filter" do
      it "filters by language" do
        filter = described_class.new({ "lang" => "deu" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to include("person")
        expect(designations).not_to include("entity")
      end

      it "returns empty for non-existent language" do
        filter = described_class.new({ "lang" => "xyz" })
        result = filter.apply(all_concepts)
        expect(result).to be_empty
      end
    end

    describe "domain filter" do
      it "filters by domain" do
        filter = described_class.new({ "domain" => "foo" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to include("entity")
        expect(designations).to include("material entity")
        expect(designations).not_to include("biological entity")
      end

      it "backward-compatible: 'group' alias still works" do
        filter = described_class.new({ "group" => "foo" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to include("entity")
      end
    end

    describe "sort_by filter" do
      it "sorts by term designation" do
        filter = described_class.new({ "sort_by" => "term" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to eq(designations.sort_by(&:downcase))
      end

      it "sorts by default_designation alias" do
        filter = described_class.new({ "sort_by" => "default_designation" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to eq(designations.sort_by(&:downcase))
      end

      it "sorts by simple nested path (data.identifier)" do
        filter = described_class.new({ "sort_by" => "data.identifier" })
        result = filter.apply(all_concepts)
        ids = result.map { |c| c.data.id }
        expect(ids).to eq(["3.1.1.1", "3.1.1.3", "3.1.1.5", "3.1.1.6"])
      end

      it "sorts by deeply nested path (English designation)" do
        filter = described_class.new({ "sort_by" => "data.localizations['eng'].data.terms[0].designation" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to eq(designations.sort_by(&:downcase))
      end

      it "sorts nil values last when path is missing for some concepts" do
        filter = described_class.new({ "lang" => "deu", "sort_by" => "data.localizations['deu'].data.terms[0].designation" })
        result = filter.apply(all_concepts)
        expect(result.length).to eq(1)
        expect(result.first.default_designation).to eq("person")
      end

      it "returns collection unchanged when sort field is nil" do
        filter = described_class.new({ "sort_by" => nil })
        result = filter.apply(all_concepts)
        expect(result.length).to eq(all_concepts.length)
      end
    end

    describe "field filter" do
      it "filters by designation equality" do
        filter = described_class.new({
                                       "data.localizations['eng'].data.terms[0].designation" => "entity",
                                     })
        result = filter.apply(all_concepts)
        expect(result.map(&:default_designation)).to eq(["entity"])
      end

      it "filters by designation start_with" do
        filter = described_class.new({
                                       "data.localizations['eng'].data.terms[0].designation.start_with(enti)" => nil,
                                     })
        result = filter.apply(all_concepts)
        expect(result.map(&:default_designation)).to eq(["entity"])
      end
    end

    describe "combined filters" do
      it "applies lang and sort_by together" do
        filter = described_class.new({ "lang" => "eng", "sort_by" => "term" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to eq(designations.sort_by(&:downcase))
        expect(designations.length).to eq(all_concepts.length)
      end

      it "applies domain and sort_by together" do
        filter = described_class.new({ "domain" => "foo", "sort_by" => "term" })
        result = filter.apply(all_concepts)
        designations = result.map(&:default_designation)
        expect(designations).to eq(["entity", "material entity"])
      end

      it "applies domain and nested sort_by together" do
        filter = described_class.new({ "domain" => "bar", "sort_by" => "data.identifier" })
        result = filter.apply(all_concepts)
        ids = result.map { |c| c.data.id }
        expect(ids).to eq(["3.1.1.5", "3.1.1.6"])
      end

      it "applies lang and nested sort_by together" do
        filter = described_class.new({ "lang" => "deu", "sort_by" => "data.identifier" })
        result = filter.apply(all_concepts)
        ids = result.map { |c| c.data.id }
        expect(ids).to eq(["3.1.1.6"])
      end
    end
  end
end
