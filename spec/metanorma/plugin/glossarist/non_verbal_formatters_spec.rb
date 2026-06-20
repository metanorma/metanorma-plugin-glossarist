# frozen_string_literal: true

require "tmpdir"

RSpec.describe Metanorma::Plugin::Glossarist::NonVerbalFormatters do
  let(:lang) { "eng" }

  describe Metanorma::Plugin::Glossarist::NonVerbalFormatters::Figure do
    let(:figure) do
      Glossarist::Figure.new(
        id: "mixed-reflection",
        identifier: "Figure 1",
        caption: { "eng" => "Mixed reflection" },
        alt: { "eng" => "Diagram showing reflection" },
        images: [
          Glossarist::FigureImage.new(src: "fig.svg", format: "svg",
                                      role: "vector"),
          Glossarist::FigureImage.new(src: "fig.png", format: "png",
                                      role: "raster",
                                      width: 1600, height: 1200),
        ],
      )
    end

    it "renders an AsciiDoc image block with anchor and caption" do
      out = described_class.new(figure, lang: lang).to_asciidoc
      expect(out).to include("[[mixed-reflection]]")
      expect(out).to include(".Mixed reflection")
      expect(out).to include("image::fig.svg[Diagram showing reflection]")
    end

    it "prefers vector role when multiple variants exist" do
      out = described_class.new(figure, lang: lang).to_asciidoc
      expect(out).to include("image::fig.svg")
      expect(out).not_to include("image::fig.png")
    end

    it "falls back to first image when no role matches priority list" do
      only = Glossarist::Figure.new(
        id: "alone",
        alt: { "eng" => "alt" },
        images: [Glossarist::FigureImage.new(src: "x.jpg", format: "jpg")],
      )
      out = described_class.new(only, lang: lang).to_asciidoc
      expect(out).to include("image::x.jpg[alt]")
    end

    it "renders subfigures recursively" do
      composite = Glossarist::Figure.new(
        id: "parent",
        caption: { "eng" => "Parent" },
        alt: { "eng" => "parent alt" },
        images: [Glossarist::FigureImage.new(src: "p.svg", format: "svg")],
        subfigures: [
          Glossarist::Figure.new(
            id: "child",
            caption: { "eng" => "Child" },
            alt: { "eng" => "child alt" },
            images: [Glossarist::FigureImage.new(src: "c.svg", format: "svg")],
          ),
        ],
      )
      out = described_class.new(composite, lang: lang).to_asciidoc
      expect(out).to include("[[parent]]")
      expect(out).to include("image::p.svg")
      expect(out).to include("[[child]]")
      expect(out).to include("image::c.svg")
    end

    it "falls back to first available language when requested lang missing" do
      figure = Glossarist::Figure.new(
        id: "f",
        caption: { "fra" => "Réflexion" },
        alt: { "fra" => "Diagramme" },
        images: [Glossarist::FigureImage.new(src: "f.svg", format: "svg")],
      )
      out = described_class.new(figure, lang: "eng").to_asciidoc
      expect(out).to include(".Réflexion")
      expect(out).to include("image::f.svg[Diagramme]")
    end
  end

  describe Metanorma::Plugin::Glossarist::NonVerbalFormatters::Table do
    let(:table) do
      Glossarist::Table.new(
        id: "units",
        identifier: "Table 1",
        caption: { "eng" => "SI base units" },
        alt: { "eng" => "SI units table" },
        content: {
          "headers" => %w[Unit Symbol],
          "rows" => [%w[metre m], %w[kilogram kg]],
        },
        format: "structured",
      )
    end

    it "renders an AsciiDoc table with anchor and caption" do
      out = described_class.new(table, lang: lang).to_asciidoc
      expect(out).to include("[[units]]")
      expect(out).to include(".SI base units")
    end

    it "renders headers and rows in structured format" do
      out = described_class.new(table, lang: lang).to_asciidoc
      expect(out).to include("|===")
      expect(out).to include("|Unit |Symbol")
      expect(out).to include("|metre |m")
      expect(out).to include("|kilogram |kg")
    end

    it "renders raw block when format is not structured" do
      raw = Glossarist::Table.new(
        id: "raw",
        caption: { "eng" => "Raw" },
        content: { "asciidoc" => "|===\n|A |B\n|1 |2\n|===" },
        format: "asciidoc",
      )
      out = described_class.new(raw, lang: lang).to_asciidoc
      expect(out).to include("[[raw]]")
      expect(out).to include(".Raw")
      expect(out).to include("|A |B")
    end
  end

  describe Metanorma::Plugin::Glossarist::NonVerbalFormatters::Formula do
    let(:formula) do
      Glossarist::Formula.new(
        id: "wave",
        identifier: "Eq. 1",
        caption: { "eng" => "Wave equation" },
        alt: { "eng" => "Wave equation alt" },
        expression: { "eng" => "E = mc^2" },
        notation: "latex",
      )
    end

    it "renders an AsciiDoc stem block with anchor and caption" do
      out = described_class.new(formula, lang: lang).to_asciidoc
      expect(out).to include("[[wave]]")
      expect(out).to include(".Wave equation")
      expect(out).to include("[stem]")
    end

    it "places the expression inside stem delimiters" do
      out = described_class.new(formula, lang: lang).to_asciidoc
      expect(out).to include("++++")
      expect(out).to include("E = mc^2")
    end

    it "renders empty body when expression is absent" do
      bare = Glossarist::Formula.new(
        id: "bare",
        caption: { "eng" => "Bare" },
      )
      out = described_class.new(bare, lang: lang).to_asciidoc
      expect(out).to include("[[bare]]")
      expect(out).not_to include("[stem]")
    end
  end
end
