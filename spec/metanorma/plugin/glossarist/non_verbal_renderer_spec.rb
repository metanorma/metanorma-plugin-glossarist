# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::NonVerbalRenderer do
  let(:v3_path) do
    File.expand_path("../../../fixtures/dataset-glossarist-v3", __dir__)
  end
  let(:all_collections) do
    {
      figures: collection_for(:figures),
      tables: collection_for(:tables),
      formulas: collection_for(:formulas),
    }
  end

  def collection_class_for(kind)
    {
      figures: Glossarist::Collections::FigureCollection,
      tables: Glossarist::Collections::TableCollection,
      formulas: Glossarist::Collections::FormulaCollection,
    }.fetch(kind)
  end

  def collection_for(kind)
    collection_class_for(kind).from_directory(File.join(v3_path, kind.to_s))
  end

  describe "#render_kind" do
    it "renders every figure in the collection" do
      renderer = described_class.new(collections: all_collections)
      out = renderer.render_kind(:figures)
      expect(out).to include("[[mixed-reflection]]")
      expect(out).to include(".Mixed reflection")
      expect(out).to include("image::figures/mixed-reflection.svg")
    end

    it "renders every table in the collection" do
      renderer = described_class.new(collections: all_collections)
      out = renderer.render_kind(:tables)
      expect(out).to include("[[unit-conversion]]")
      expect(out).to include("|===")
      expect(out).to include("|Unit |Symbol |Dimension")
    end

    it "renders every formula in the collection" do
      renderer = described_class.new(collections: all_collections)
      out = renderer.render_kind(:formulas)
      expect(out).to include("[[wave-equation]]")
      expect(out).to include("[stem]")
    end

    it "returns empty string when collection is nil" do
      renderer = described_class.new(collections: {})
      expect(renderer.render_kind(:figures)).to eq("")
    end
  end

  describe "#render_concept_refs" do
    let(:concept) do
      c = Glossarist::ManagedConceptCollection.new
      c.load_from_files(v3_path)
      c.find { |x| x.data&.id == "1.1" }
    end

    it "renders all referenced non-verbal entities for a concept" do
      renderer = described_class.new(collections: all_collections)
      out = renderer.render_concept_refs(concept)
      expect(out).to include("[[mixed-reflection]]")
      expect(out).to include("[[unit-conversion]]")
      expect(out).to include("[[wave-equation]]")
    end

    it "renders in figures → tables → formulas order" do
      renderer = described_class.new(collections: all_collections)
      out = renderer.render_concept_refs(concept)
      expect(out.index("[[mixed-reflection]]"))
        .to be < out.index("[[unit-conversion]]")
      expect(out.index("[[unit-conversion]]"))
        .to be < out.index("[[wave-equation]]")
    end

    it "skips refs whose entity is missing from the collection" do
      concept.data.figures.first.entity_id = "missing-fig"
      renderer = described_class.new(collections: all_collections)
      out = renderer.render_concept_refs(concept)
      expect(out).not_to include("[[mixed-reflection]]")
      expect(out).to include("[[unit-conversion]]")
    end

    it "returns empty string when concept has no non-verbal refs" do
      bare = Glossarist::ManagedConceptCollection.new
      bare.load_from_files(
        File.expand_path("../../../fixtures/dataset-glossarist-v2", __dir__),
      )
      renderer = described_class.new(collections: all_collections)
      expect(renderer.render_concept_refs(bare.first)).to eq("")
    end
  end
end
