# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Sanitize do
  describe ".extract_xrefs" do
    it "extracts a single AsciiDoc xref" do
      expect(described_class.extract_xrefs("see <<ISO_11179_1>>"))
        .to eq(["ISO_11179_1"])
    end

    it "extracts xref without display text" do
      expect(described_class.extract_xrefs("see <<ref_25>>"))
        .to eq(["ref_25"])
    end

    it "extracts xref target ignoring display text" do
      text = "see <<ISO_11179_1,ISO 11179-1>>"
      expect(described_class.extract_xrefs(text))
        .to eq(["ISO_11179_1"])
    end

    it "extracts multiple unique xrefs" do
      text = "see <<ISO_11179_1>> and <<ISO19505_2_2012>> then <<ISO_11179_1>>"
      expect(described_class.extract_xrefs(text))
        .to eq(%w[ISO_11179_1 ISO19505_2_2012])
    end

    it "returns empty array for nil" do
      expect(described_class.extract_xrefs(nil)).to eq([])
    end

    it "returns empty array for string with no xrefs" do
      expect(described_class.extract_xrefs("plain text")).to eq([])
    end
  end
end
