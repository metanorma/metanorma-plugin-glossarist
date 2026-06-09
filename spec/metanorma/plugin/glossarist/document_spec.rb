# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Document do
  describe "#add_content" do
    it "stores raw content without rendering" do
      doc = described_class.new
      doc.add_content("some text")
      expect(doc.to_s).to eq("some text")
    end

    it "renders liquid content when render option is true" do
      doc = described_class.new
      doc.add_content("{{ 1 | plus: 1 }}", render: true)
      expect(doc.to_s).to eq("2")
    end

    it "accumulates multiple content blocks" do
      doc = described_class.new
      doc.add_content("line one")
      doc.add_content("line two")
      expect(doc.to_s).to eq("line one\nline two")
    end

    it "skips nil content" do
      doc = described_class.new
      doc.add_content("kept")
      doc.add_content(nil)
      expect(doc.to_s).to eq("kept")
    end
  end

  describe "#to_s" do
    it "joins content with newlines" do
      doc = described_class.new
      doc.add_content("a")
      doc.add_content("b")
      doc.add_content("c")
      expect(doc.to_s).to eq("a\nb\nc")
    end

    it "returns empty string for no content" do
      doc = described_class.new
      expect(doc.to_s).to eq("")
    end
  end

  describe "#file_system" do
    it "allows setting file_system" do
      doc = described_class.new
      doc.file_system = "/tmp"
      expect(doc.file_system).to eq("/tmp")
    end
  end
end
