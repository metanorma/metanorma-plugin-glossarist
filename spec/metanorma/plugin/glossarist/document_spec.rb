# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Document do
  describe "#add_raw" do
    it "stores content without rendering" do
      doc = described_class.new
      doc.add_raw("some text")
      expect(doc.to_s).to eq("some text")
    end

    it "accumulates multiple raw blocks" do
      doc = described_class.new
      doc.add_raw("line one")
      doc.add_raw("line two")
      expect(doc.to_s).to eq("line one\nline two")
    end

    it "skips nil content" do
      doc = described_class.new
      doc.add_raw("kept")
      doc.add_raw(nil)
      expect(doc.to_s).to eq("kept")
    end
  end

  describe "#add_rendered" do
    it "renders Liquid content" do
      doc = described_class.new
      doc.add_rendered("{{ 1 | plus: 1 }}")
      expect(doc.to_s).to eq("2")
    end

    it "passes the template option through to the renderer" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "_tpl.liquid"), "rendered: {{ x }}")
        doc = described_class.new
        doc.add_rendered("{% render 'tpl' %}", template: dir)
        expect(doc.to_s).to include("rendered:")
      end
    end
  end

  describe "#to_s" do
    it "joins content with newlines" do
      doc = described_class.new
      doc.add_raw("a")
      doc.add_raw("b")
      doc.add_raw("c")
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
