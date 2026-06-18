# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::SectionRenderer do
  let(:v3_path) do
    File.expand_path("../../../fixtures/dataset-glossarist-v3", __dir__)
  end

  let(:collection) do
    c = Glossarist::ManagedConceptCollection.new
    c.load_from_files(v3_path)
    c
  end

  let(:register) { Glossarist::DatasetRegister.from_directory(v3_path) }
  let(:sections) { register.sections }

  def new_renderer(dataset: collection.to_a, **opts)
    renderer = Metanorma::Plugin::Glossarist::TemplateRenderer.new(
      file_system: File.dirname(v3_path),
    )
    described_class.new(
      dataset: dataset, register: register,
      renderer: renderer, **opts
    )
  end

  describe "#render" do
    it "renders one block per non-empty section" do
      parts = new_renderer(depth: 2).render(sections)
      expect(parts.length).to eq(1)
      expect(parts.first).to start_with("=== ")
    end

    it "uses section name in heading when available" do
      parts = new_renderer(depth: 2).render(sections)
      section = register.section_by_id("3")
      expect(parts.first).to include("=== #{section.name}")
    end

    it "cascades ancestor section membership via register" do
      only_section_three = sections.select { |s| s.id == "3" }
      body = new_renderer(depth: 2).render(only_section_three).first
      expect(body).to include("parent concept")
      expect(body).to include("child concept")
    end

    it "skips sections that have no matching concepts" do
      parts = new_renderer(depth: 2).render(sections)
      expect(parts.length).to eq(1)
    end

    it "yields matched concepts to the caller" do
      accumulated = []
      new_renderer(depth: 2).render(sections) do |concepts|
        accumulated.concat(concepts)
      end
      ids = accumulated.map { |c| c.data&.id }
      expect(ids).to include("1.1", "1.1.1")
    end

    it "respects custom sort_by option" do
      default = new_renderer(depth: 2)
      custom = new_renderer(depth: 2, sort_by: "data.id")
      expect(default.render(sections)).not_to be_empty
      expect(custom.render(sections)).not_to be_empty
    end

    it "renders heading at depth + 1" do
      parts = new_renderer(depth: 3).render(sections)
      expect(parts.first).to start_with("==== ")
    end

    it "passes anchor_prefix to the concept renderer" do
      parts = new_renderer(depth: 2, anchor_prefix: "pre").render(sections)
      expect(parts.first).to include("[[pre1.1]]")
    end
  end
end
