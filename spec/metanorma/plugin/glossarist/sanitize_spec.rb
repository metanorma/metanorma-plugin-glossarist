# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Sanitize do
  describe ".references" do
    it "replaces URN references with NCName anchors" do
      input = "{{urn:iso:std:iso:34000,Some Term}}rest"
      result = described_class.references(input)
      expect(result).to match(/{{[^,}]+,Some Term}}rest/)
    end

    it "returns string unchanged when no URN references" do
      input = "plain text without references"
      expect(described_class.references(input)).to eq(input)
    end

    it "returns nil for nil input" do
      expect(described_class.references(nil)).to be_nil
    end

    it "replaces first URN reference (regex consumes rest of string)" do
      input = "{{urn:iso:std:iso:34000,Term A}}rest"
      result = described_class.references(input)
      expect(result).not_to include("urn:iso:std:iso:34000")
    end

    it "leaves non-URN mentions untouched" do
      input = "{{cite:foo}} and {{fig:bar}} proceed"
      expect(described_class.references(input)).to eq(input)
    end
  end
end
