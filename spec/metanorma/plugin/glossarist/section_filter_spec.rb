# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::SectionFilter do
  let(:sections) do
    [
      Glossarist::Section.new(id: "3", names: { "eng" => "Section 3" }),
      Glossarist::Section.new(id: "3.1", names: { "eng" => "Section 3.1" }),
      Glossarist::Section.new(id: "4", names: { "eng" => "Section 4" }),
    ]
  end

  describe "#apply" do
    it "returns all sections with no filters" do
      filter = described_class.new
      result = filter.apply(sections)
      expect(result.length).to eq(3)
    end

    it "excludes sections matching exclude patterns" do
      filter = described_class.new(exclude: ["3"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).not_to include("3")
      expect(ids).not_to include("3.1")
      expect(ids).to include("4")
    end

    it "includes only sections matching include patterns" do
      filter = described_class.new(include: ["3"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to include("3")
      expect(ids).to include("3.1")
      expect(ids).not_to include("4")
    end

    it "excludes take priority over includes" do
      filter = described_class.new(include: ["3"], exclude: ["3.1"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to include("3")
      expect(ids).not_to include("3.1")
    end

    it "handles empty string patterns by ignoring them" do
      filter = described_class.new(exclude: [""], include: [""])
      result = filter.apply(sections)
      expect(result.length).to eq(3)
    end

    it "returns empty array for empty sections input" do
      filter = described_class.new
      result = filter.apply([])
      expect(result).to eq([])
    end

    it "handles multiple exclude patterns" do
      filter = described_class.new(exclude: ["3.", "4"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to eq(["3"])
    end

    it "handles multiple include patterns" do
      filter = described_class.new(include: ["3.1", "4"])
      result = filter.apply(sections)
      ids = result.map(&:id)
      expect(ids).to contain_exactly("3.1", "4")
    end
  end

  describe "#apply with a hierarchical register" do
    let(:tree) do
      [
        Glossarist::Section.new(
          id: "modules",
          names: { "eng" => "Application Modules" },
          children: [
            Glossarist::Section.new(
              id: "Activity_arm",
              names: { "eng" => "Module: Activity (ARM)" },
            ),
            Glossarist::Section.new(
              id: "Activity_mim",
              names: { "eng" => "Module: Activity (MIM)" },
            ),
          ],
        ),
        Glossarist::Section.new(
          id: "resources",
          names: { "eng" => "Resources" },
          children: [
            Glossarist::Section.new(
              id: "action_schema",
              names: { "eng" => "Resource: Action" },
            ),
          ],
        ),
      ]
    end

    let(:populated) { %w[Activity_arm Activity_mim action_schema] }

    it "includes matching leaf sections" do
      filter = described_class.new(include: ["_arm", "_mim"])
      expect(filter.apply(tree, populated: populated).map(&:id))
        .to eq(%w[Activity_arm Activity_mim])
    end

    it "excludes matching leaf sections only" do
      filter = described_class.new(exclude: ["_arm", "_mim"])
      expect(filter.apply(tree, populated: populated).map(&:id))
        .to eq(%w[action_schema])
    end

    it "never returns a structural section" do
      ids = described_class.new.apply(tree, populated: populated).map(&:id)
      expect(ids).not_to include("modules", "resources")
    end

    it "keeps a section that owns concepts instead of descending into it" do
      mixed = [
        Glossarist::Section.new(
          id: "3",
          names: { "eng" => "Terms related to testing" },
          children: [
            Glossarist::Section.new(
              id: "3.1",
              names: { "eng" => "Nested testing subsection" },
            ),
          ],
        ),
      ]
      ids = described_class.new.apply(mixed, populated: ["3"]).map(&:id)
      expect(ids).to eq(["3"])
    end

    it "filters the sections as given when no populated set is supplied" do
      filter = described_class.new(include: ["resources"])
      expect(filter.apply(tree).map(&:id)).to eq(%w[resources])
    end
  end
end
