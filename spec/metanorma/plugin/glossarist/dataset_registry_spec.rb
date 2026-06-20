# frozen_string_literal: true

require "tmpdir"

RSpec.describe Metanorma::Plugin::Glossarist::DatasetRegistry do
  let(:v2_path) do
    File.expand_path("../../../fixtures/dataset-glossarist-v2", __dir__)
  end
  let(:v3_path) do
    File.expand_path("../../../fixtures/dataset-glossarist-v3", __dir__)
  end

  def document_double
    docfile = File.join(Dir.tmpdir, "test.adoc")
    resolver = Asciidoctor::PathResolver.new
    doc = Struct.new(:attributes, :path_resolver).new(
      { "docfile" => docfile }, resolver
    )
    # Warm up the path resolver's internal state
    resolver.system_path("", File.dirname(docfile))
    doc
  end

  describe "#register" do
    it "loads a dataset and returns context paths" do
      registry = described_class.new
      paths = registry.register(document_double, "dataset1:#{v2_path}")
      expect(paths).to eq(["dataset1=#{v2_path}"])
    end

    it "loads multiple datasets from semicolon-separated contexts" do
      registry = described_class.new
      paths = registry.register(document_double,
                                "ds1:#{v2_path};ds2:#{v3_path}")
      expect(paths.length).to eq(2)
      expect(paths[0]).to start_with("ds1=")
      expect(paths[1]).to start_with("ds2=")
    end

    it "makes registered datasets resolvable by name" do
      registry = described_class.new
      registry.register(document_double, "myset:#{v2_path}")
      dataset = registry.resolve_dataset(nil, "myset")
      expect(dataset).not_to be_nil
      expect(dataset.length).to be > 0
    end
  end

  describe "#resolve_dataset" do
    it "returns nil for unregistered dataset without document" do
      registry = described_class.new
      expect(registry.resolve_dataset(nil, "missing")).to be_nil
    end

    it "lazy-loads a dataset by path via document" do
      registry = described_class.new
      result = registry.resolve_dataset(document_double, v2_path)
      expect(result).not_to be_nil
      expect(result.length).to be > 0
    end

    it "caches lazily-loaded datasets" do
      registry = described_class.new
      first = registry.resolve_dataset(document_double, v2_path)
      second = registry.resolve_dataset(document_double, v2_path)
      expect(first).to equal(second)
    end
  end

  describe "#find_concept" do
    it "finds a concept by designation" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      concept = registry.find_concept("ds", "entity")
      expect(concept).not_to be_nil
      expect(concept.default_designation).to eq("entity")
    end

    it "returns nil for unknown concept" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      expect(registry.find_concept("ds", "nonexistent")).to be_nil
    end
  end

  describe "#context_path" do
    it "returns path for registered context name" do
      registry = described_class.new
      registry.register(document_double, "myctx:#{v2_path}")
      expect(registry.context_path("myctx")).to eq(v2_path)
    end

    it "returns nil for unknown context name" do
      registry = described_class.new
      expect(registry.context_path("unknown")).to be_nil
    end

    it "returns nil when no contexts registered" do
      registry = described_class.new
      expect(registry.context_path("anything")).to be_nil
    end
  end

  describe "#register_sections" do
    it "returns Section objects from register.yaml" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      sections = registry.register_sections("ds")
      expect(sections).not_to be_nil
      expect(sections.length).to eq(2)
      expect(sections.first).to be_a(Glossarist::Section)
      expect(sections.map(&:id)).to include("3", "other")
    end

    it "returns nil for unregistered context name" do
      registry = described_class.new
      expect(registry.register_sections("unknown")).to be_nil
    end

    it "returns nil when register.yaml does not exist" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      expect(registry.register_sections("ds")).to be_nil
    end

    it "caches the parsed register across calls" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      first = registry.register_sections("ds")
      second = registry.register_sections("ds")
      expect(first).to equal(second) # same object identity
    end
  end

  describe "#bibliography_for" do
    it "returns nil when no bibliography.yaml exists" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      expect(registry.bibliography_for("ds")).to be_nil
    end

    it "loads typed BibliographyData from a V3 dataset" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      bibliography = registry.bibliography_for("ds")
      expect(bibliography).to be_a(Glossarist::BibliographyData)
    end

    it "exposes typed BibliographyEntry accessors from a V3 dataset" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      iev = registry.bibliography_for("ds").find("ievtermbank")
      expect(iev).to be_a(Glossarist::BibliographyEntry)
      expect(iev.title).to eq("IEV: Electropedia")
      expect(iev.reference).to eq("IEV")
      expect(iev.type).to eq("termbank")
    end

    it "caches the bibliography across calls" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      first = registry.bibliography_for("ds")
      second = registry.bibliography_for("ds")
      expect(first).to equal(second)
    end

    it "returns nil for an unknown context name" do
      registry = described_class.new
      expect(registry.bibliography_for("unknown")).to be_nil
    end
  end

  describe "#non_verbal_collection" do
    it "loads a FigureCollection from a V3 dataset" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      coll = registry.non_verbal_collection("ds", :figures)
      expect(coll).to be_a(Glossarist::Collections::FigureCollection)
      expect(coll.ids).to include("mixed-reflection")
    end

    it "loads a TableCollection from a V3 dataset" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      coll = registry.non_verbal_collection("ds", :tables)
      expect(coll).to be_a(Glossarist::Collections::TableCollection)
      expect(coll.ids).to include("unit-conversion")
    end

    it "loads a FormulaCollection from a V3 dataset" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      coll = registry.non_verbal_collection("ds", :formulas)
      expect(coll).to be_a(Glossarist::Collections::FormulaCollection)
      expect(coll.ids).to include("wave-equation")
    end

    it "returns nil when the subdirectory is absent" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      expect(registry.non_verbal_collection("ds", :figures)).to be_nil
    end

    it "raises ArgumentError for an unknown kind" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      expect do
        registry.non_verbal_collection("ds", :bogus)
      end.to raise_error(ArgumentError, /unknown non-verbal kind/)
    end

    it "caches collections across calls" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      first = registry.non_verbal_collection("ds", :figures)
      second = registry.non_verbal_collection("ds", :figures)
      expect(first).to equal(second)
    end
  end

  describe "dynamic accessors" do
    it "exposes figures_for, tables_for, formulas_for methods" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      expect(registry.figures_for("ds")).to be_a(Glossarist::Collections::FigureCollection)
      expect(registry.tables_for("ds")).to be_a(Glossarist::Collections::TableCollection)
      expect(registry.formulas_for("ds")).to be_a(Glossarist::Collections::FormulaCollection)
    end
  end

  describe "#non_verbal_collections" do
    it "returns a hash of all available kinds" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v3_path}")
      hash = registry.non_verbal_collections("ds")
      expect(hash.keys).to contain_exactly(:figures, :tables, :formulas)
      expect(hash[:figures]).to be_a(Glossarist::Collections::FigureCollection)
    end

    it "returns empty hash when no subdirectories exist" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      expect(registry.non_verbal_collections("ds")).to eq({})
    end

    it "returns empty hash for unregistered context" do
      registry = described_class.new
      expect(registry.non_verbal_collections("missing")).to eq({})
    end
  end
end
