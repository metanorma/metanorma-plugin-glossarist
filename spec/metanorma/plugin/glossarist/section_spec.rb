# frozen_string_literal: true

RSpec.describe Glossarist::Section do
  describe "#id" do
    it "returns the section id" do
      section = described_class.new(id: "3", names: { "eng" => "Terms" })
      expect(section.id).to eq("3")
    end
  end

  describe "#names" do
    it "returns the names hash" do
      section = described_class.new(id: "3", names: { "eng" => "Terms" })
      expect(section.names).to eq({ "eng" => "Terms" })
    end
  end

  describe "#name" do
    it "returns the English name with no args" do
      section = described_class.new(id: "3", names: { "eng" => "Terms" })
      expect(section.name).to eq("Terms")
    end

    it "returns the name for a given language" do
      section = described_class.new(id: "3", names: { "fra" => "Termes",
                                                      "eng" => "Terms" })
      expect(section.name("fra")).to eq("Termes")
    end

    it "falls back to English for unknown language" do
      section = described_class.new(id: "3", names: { "eng" => "Terms" })
      expect(section.name("deu")).to eq("Terms")
    end

    it "returns nil when no English name" do
      section = described_class.new(id: "3")
      expect(section.name).to be_nil
    end
  end

  describe "hierarchical children" do
    let(:child) { described_class.new(id: "3.1", names: { "eng" => "Sub" }) }
    let(:parent) do
      described_class.new(id: "3", names: { "eng" => "Parent" },
                          children: [child])
    end

    it "has children" do
      expect(parent.children.length).to eq(1)
      expect(parent.children.first.id).to eq("3.1")
    end

    it "finds descendant by id" do
      found = parent.descendant_by_id("3.1")
      expect(found).not_to be_nil
      expect(found.id).to eq("3.1")
    end
  end
end
