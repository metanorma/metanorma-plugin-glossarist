# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::SectionCascade do
  let(:v3_path) do
    File.expand_path("../../../fixtures/dataset-glossarist-v3", __dir__)
  end

  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files(v3_path)
    c
  end

  let(:register) { Glossarist::DatasetRegister.from_directory(v3_path) }

  let(:parent_concept) { collection.find { |c| c.data&.id == "1.1" } }
  let(:child_concept) { collection.find { |c| c.data&.id == "1.1.1" } }

  describe "with a DatasetRegister (V3 canonical)" do
    it "matches the concept's direct section" do
      cascade = described_class.new(register)
      expect(cascade.member?(parent_concept, "3")).to be(true)
    end

    it "cascades to ancestor sections" do
      cascade = described_class.new(register)
      # 1.1.1 has explicit domain 3.1; cascading should match ancestor 3
      expect(cascade.member?(child_concept, "3.1")).to be(true)
      expect(cascade.member?(child_concept, "3")).to be(true)
    end

    it "does not match a sibling section" do
      cascade = described_class.new(register)
      expect(cascade.member?(child_concept, "other")).to be(false)
    end

    it "does not match a descendant the concept is not in" do
      cascade = described_class.new(register)
      # parent concept 1.1 is in section 3 directly, not 3.1
      expect(cascade.member?(parent_concept, "3.1")).to be(false)
    end
  end

  describe "without a register (legacy fallback)" do
    it "matches the concept's explicit domain section" do
      cascade = described_class.new(nil)
      expect(cascade.member?(parent_concept, "3")).to be(true)
    end

    it "matches the concept's explicit nested section" do
      cascade = described_class.new(nil)
      expect(cascade.member?(child_concept, "3.1")).to be(true)
    end

    it "cannot cascade to ancestor without a register" do
      cascade = described_class.new(nil)
      expect(cascade.member?(child_concept, "3")).to be(false)
    end
  end

  describe "edge cases" do
    it "returns false for nil concept" do
      expect(described_class.new(register).member?(nil, "3")).to be(false)
    end

    it "returns false for concept without data" do
      cascade = described_class.new(register)
      bare = Struct.new(:data).new(nil)
      expect(cascade.member?(bare, "3")).to be(false)
    end
  end
end
