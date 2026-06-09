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

  describe "#bibliography_data" do
    it "returns empty hash when no bibliography.yaml exists" do
      registry = described_class.new
      registry.register(document_double, "ds:#{v2_path}")
      expect(registry.bibliography_data).to eq({})
    end

    it "loads bibliography data from YAML file" do
      Dir.mktmpdir do |dir|
        bib = [{ "id" => "ref1", "title" => "Test Reference" }]
        File.write(File.join(dir, "bibliography.yaml"), bib.to_yaml)
        FileUtils.mkdir_p(File.join(dir, "concept"))

        registry = described_class.new
        registry.register(document_double, "ds:#{dir}")
        expect(registry.bibliography_data).to eq({ "ref1" => bib[0] })
      end
    end
  end
end
