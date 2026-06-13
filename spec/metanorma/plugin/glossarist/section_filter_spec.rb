# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::SectionFilter do
  let(:sections) do
    [
      Glossarist::Section.new(id: "3", names: { "eng" => "Section 3" }),
      Glossarist::Section.new(id: "3.1", names: { "eng" => "Section 3.1" }),
      Glossarist::Section.new(id: "4", names: { "eng" => "Section 4" }),
    ]
  end

  describe "#apply" do
    it "returns all sections with no filters" do
      filter = described_class.new
      result = filter.apply(sections)
      expect(result.length).to eq(3)
    end

    it "excludes sections matching exclude patterns" do
      filter = described_class.new(exclude: ["3"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).not_to include("3")
      expect(ids).not_to include("3.1")
      expect(ids).to include("4")
    end

    it "includes only sections matching include patterns" do
      filter = described_class.new(include: ["3"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to include("3")
      expect(ids).to include("3.1")
      expect(ids).not_to include("4")
    end

    it "excludes take priority over includes" do
      filter = described_class.new(include: ["3"], exclude: ["3.1"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to include("3")
      expect(ids).not_to include("3.1")
    end

    it "handles empty string patterns by ignoring them" do
      filter = described_class.new(exclude: [""], include: [""])
      result = filter.apply(sections)
      expect(result.length).to eq(3)
    end

    it "returns empty array for empty sections input" do
      filter = described_class.new
      result = filter.apply([])
      expect(result).to eq([])
    end

    it "handles multiple exclude patterns" do
      filter = described_class.new(exclude: ["3.", "4"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to eq(["3"])
    end

    it "handles multiple include patterns" do
      filter = described_class.new(include: ["3.1", "4"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to contain_exactly("3.1", "4")
    end
  end
end
