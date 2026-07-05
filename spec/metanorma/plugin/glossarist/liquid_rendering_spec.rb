# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::LiquidRendering do
  describe ".render" do
    it "renders a simple Liquid template" do
      out = described_class.render("hello {{ name }}",
                                   include_paths: [],
                                   assigns: { "name" => "world" })
      expect(out).to eq("hello world")
    end

    it "wires the LocalFileSystem into template registers" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "_partial.liquid"), "from partial")
        out = described_class.render("{% render 'partial' %}",
                                     include_paths: [dir],
                                     assigns: {})
        expect(out).to eq("from partial")
      end
    end

    it "wires the dataset_registry into template registers when provided" do
      sentinel = Class.new(Liquid::Tag) do
        def render(context)
          "registry:#{context.registers[:dataset_registry].object_id}"
        end
      end
      Liquid::Environment.default.register_tag("sentinel", sentinel)
      registry = Object.new

      out = described_class.render("{% sentinel %}",
                                   include_paths: [],
                                   assigns: {},
                                   registry: registry)
      expect(out).to eq("registry:#{registry.object_id}")
    ensure
      Liquid::Environment.default.tags.delete("sentinel")
    end

    it "re-raises the first Liquid error when rendering fails" do
      broken = "{% undefined_tag_foo_bar %}"
      expect { described_class.render(broken, include_paths: []) }
        .to raise_error(Liquid::Error)
    end
  end
end
