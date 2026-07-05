# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::FieldFilter do
  StubResolver = Struct.new(:map, keyword_init: true) do
    def resolve(_concept, path)
      map[path]
    end
  end

  let(:resolver) { StubResolver.new(map: { "data.title" => "alpha" }) }

  def concept_stub; end

  describe ".from_options_entry" do
    it "builds an :eq matcher from a plain path key" do
      ff = described_class.from_options_entry("data.title", "alpha")
      expect(ff.matcher).to eq(:eq)
      expect(ff.path).to eq("data.title")
      expect(ff.value).to eq("alpha")
    end

    it "builds a :start_with matcher from key.start_with(pattern)" do
      ff = described_class.from_options_entry("data.title.start_with(abc)", nil)
      expect(ff.matcher).to eq(:start_with)
      expect(ff.path).to eq("data.title")
      expect(ff.value).to eq("abc")
    end

    it "treats start_with value as the literal pattern even when hash value present" do
      ff = described_class.from_options_entry("data.name.start_with(zz)",
                                              "ignored")
      expect(ff.matcher).to eq(:start_with)
      expect(ff.value).to eq("zz")
    end
  end

  describe "#match?" do
    it "matches equality when value equals resolved path" do
      ff = described_class.from_options_entry("data.title", "alpha")
      expect(ff.match?(resolver, concept_stub)).to be(true)
    end

    it "does not match equality when value differs" do
      ff = described_class.from_options_entry("data.title", "beta")
      expect(ff.match?(resolver, concept_stub)).to be(false)
    end

    it "matches start_with when resolved value starts with pattern" do
      ff = described_class.from_options_entry("data.title.start_with(al)", nil)
      expect(ff.match?(resolver, concept_stub)).to be(true)
    end

    it "does not match start_with when resolved value misses the prefix" do
      ff = described_class.from_options_entry("data.title.start_with(zz)", nil)
      expect(ff.match?(resolver, concept_stub)).to be(false)
    end

    it "does not match when path resolves to nil" do
      ff = described_class.from_options_entry("data.title", "alpha")
      empty_resolver = StubResolver.new(map: {})
      expect(ff.match?(empty_resolver, concept_stub)).to be(false)
    end
  end
end
