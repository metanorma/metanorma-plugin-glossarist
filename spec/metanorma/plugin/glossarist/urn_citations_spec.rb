# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Sanitize do
  describe ".resolve_urn_citations" do
    it "rewrites term-URN citations to anchor xrefs" do
      expect(described_class.resolve_urn_citations(
        'about "{{urn:example:term:a.concept2,concept 2}}" here',
      )).to eq 'about "<<a.concept2,concept 2>>" here'
    end

    it "rewrites tech-URN citations" do
      expect(described_class.resolve_urn_citations(
        "{{urn:example:tech:Schema.Entity,entity}}",
      )).to eq "<<Schema.Entity,entity>>"
    end

    it "rewrites bib citations to xrefs on the bibliography anchors" do
      expect(described_class.resolve_urn_citations(
        "{{bib:ECMA_262}} and {{plain word}}",
      )).to eq "<<ECMA_262>> and {{plain word}}"
    end

    it "leaves content without citations untouched" do
      expect(described_class.resolve_urn_citations(
        "no citations here",
      )).to eq "no citations here"
    end

    it "passes through nil" do
      expect(described_class.resolve_urn_citations(nil)).to be_nil
    end
  end
end

RSpec.describe "glossarist::import_sections on a register-less dataset" do
  let(:input) do
    <<~TEXT
      = Document title
      Author
      :nodoc:
      :novalid:
      :no-isobib:
      :imagesdir: spec/assets
      :glossarist-dataset: concepts:./spec/fixtures/dataset-no-register

      == Terms

      glossarist::import_sections[concepts, sort_by=term]
    TEXT
  end

  it "renders every concept section and resolves urn citations" do
    xml = metanorma_convert(input)

    # Auto-derived sections render all three concepts
    expect(xml).to include("concept1")
    expect(xml).to include("concept2")
    expect(xml).to include("concept3")

    # The urn citation resolves to an xref on the target concept's
    # rendered anchor, not a raw urn or an errormsg
    expect(xml).to include('target="a.concept2"')
    expect(xml).not_to include("urn:example:term:")
    expect(xml).not_to include("errormsg")
  end
end
