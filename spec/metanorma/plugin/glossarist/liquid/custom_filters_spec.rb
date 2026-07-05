# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::CustomFilters::Filters do
  before do
    described_class.register!
  end

  describe "#values" do
    it "returns hash values" do
      template = Liquid::Template.parse("{{ h | values | join: ',' }}")
      out = template.render("h" => { "a" => 1, "b" => 2 })
      expect(out).to eq("1,2")
    end
  end

  describe "#sanitize_references" do
    it "rewrites URN mentions to NCName-safe anchors via Liquid filter" do
      template = Liquid::Template.parse("{{ x | sanitize_references }}")
      out = template.render("x" => "{{urn:iso:std:iso:34000,Term}}")
      expect(out).not_to include("urn:iso")
    end

    it "returns plain text unchanged" do
      template = Liquid::Template.parse("{{ x | sanitize_references }}")
      out = template.render("x" => "plain")
      expect(out).to eq("plain")
    end
  end

  describe "#format_ref" do
    it "rewrites characters that are invalid in NCName anchors" do
      template = Liquid::Template.parse("{{ x | format_ref }}")
      out = template.render("x" => "ISO/TS 14812:2022")
      expect(out).to eq("ISO_TS_14812_2022")
    end

    it "returns empty string for nil input" do
      template = Liquid::Template.parse("[{{ x | format_ref }}]")
      out = template.render("x" => nil)
      expect(out).to eq("[]")
    end

    it "returns empty string for whitespace-only input" do
      template = Liquid::Template.parse("[{{ x | format_ref }}]")
      out = template.render("x" => "   ")
      expect(out).to eq("[]")
    end
  end
end
