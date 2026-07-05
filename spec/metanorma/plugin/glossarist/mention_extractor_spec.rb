# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::MentionExtractor do
  describe "#bibliography_ids" do
    it "extracts AsciiDoc xref anchors" do
      extractor = described_class.new("see <<ISO_11179_1>>")
      expect(extractor.bibliography_ids).to eq(["ISO_11179_1"])
    end

    it "extracts xref target ignoring display text" do
      text = "see <<ISO_11179_1,ISO 11179-1>>"
      extractor = described_class.new(text)
      expect(extractor.bibliography_ids).to eq(["ISO_11179_1"])
    end

    it "extracts {{cite:id}} mention IDs" do
      extractor = described_class.new("see {{cite:ievtermbank}}")
      expect(extractor.bibliography_ids).to eq(["ievtermbank"])
    end

    it "combines xref and cite mentions, deduplicated" do
      text = "<<ievtermbank>> and {{cite:iso_123}} then <<ievtermbank>>"
      extractor = described_class.new(text)
      expect(extractor.bibliography_ids).to contain_exactly("ievtermbank",
                                                            "iso_123")
    end

    it "ignores non-bibliography mentions (fig/table/formula/urn)" do
      text = "{{fig:diagram}} {{table:t1}} {{formula:f1}} {{urn:iso:std:iso:1}}"
      extractor = described_class.new(text)
      expect(extractor.bibliography_ids).to eq([])
    end

    it "returns [] for nil text" do
      extractor = described_class.new(nil)
      expect(extractor.bibliography_ids).to eq([])
    end

    it "returns [] for plain text without mentions" do
      extractor = described_class.new("plain text")
      expect(extractor.bibliography_ids).to eq([])
    end
  end
end
