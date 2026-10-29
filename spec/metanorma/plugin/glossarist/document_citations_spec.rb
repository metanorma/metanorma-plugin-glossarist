# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::DocumentCitations do
  let(:register_path) do
    File.expand_path("../../../fixtures/document-citation-register", __dir__)
  end

  def build_registry
    registry = Metanorma::Plugin::Glossarist::DatasetRegistry.new
    registry.register(nil, "concepts:#{register_path}")
    registry
  end

  def urn_citation(source: nil, id: nil)
    Glossarist::Citation.new(
      ref: Glossarist::Citation::Ref.new(
        source: source || "urn:iso:std:iso:10303:-2:ed-1:en:tech:Activity_arm:tech:Activity_arm",
        id: id || "Activity_arm",
      ),
    )
  end

  it "resolves a tech URN to the registered dataset's reference" do
    resolved = described_class.new(build_registry).resolve(urn_citation)
    expect(resolved).to eq(
      anchor: "urn_iso_std_iso_10303_-2_ed-1_en",
      citeas: "ISO 10303-2",
      locality: "locality:tech=Activity_arm",
    )
  end

  it "falls back to the URN as citeas when no register matches" do
    resolved = described_class.new(build_registry).resolve(
      urn_citation(source: "urn:iso:std:iec:60050:ed-1:en:term:voltage"),
    )
    expect(resolved[:anchor]).to eq("urn_iso_std_iec_60050_ed-1_en")
    expect(resolved[:citeas]).to eq("urn:iso:std:iec:60050:ed-1:en")
    expect(resolved[:locality]).to eq("locality:term=voltage")
  end

  it "returns a bare xref for a URN without an item path" do
    resolved = described_class.new(build_registry).resolve(
      urn_citation(source: "urn:iso:std:iso:10303:-2:ed-1:en"),
    )
    expect(resolved[:anchor]).to eq("urn_iso_std_iso_10303_-2_ed-1_en")
    expect(resolved[:citeas]).to eq("ISO 10303-2")
    expect(resolved[:locality]).to be_nil
  end

  it "returns nil for a non-URN citation" do
    citation = Glossarist::Citation.new(
      ref: Glossarist::Citation::Ref.new(source: "ISO", id: "34000:2023"),
    )
    expect(described_class.new(build_registry).resolve(citation)).to be_nil
  end

  it "returns nil for a nil citation" do
    expect(described_class.new(build_registry).resolve(nil)).to be_nil
  end

  it "memoizes per document URN" do
    resolver = described_class.new(build_registry)
    first = resolver.resolve(urn_citation)
    expect(resolver.resolve(urn_citation)).to equal(first)
  end

  it "resolves against registers added after construction" do
    mutable = Metanorma::Plugin::Glossarist::DatasetRegistry.new
    resolver = described_class.new(mutable)
    mutable.register(nil, "concepts:#{register_path}")
    expect(resolver.resolve(urn_citation)[:citeas]).to eq("ISO 10303-2")
  end
end
