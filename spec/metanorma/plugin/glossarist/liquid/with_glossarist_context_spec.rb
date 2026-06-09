# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::WithGlossaristContext do
  before do
    described_class.register!
  end

  it "registers without error and can be parsed" do
    expect do
      Liquid::Template.parse("{% with_glossarist_context test=/nonexistent %}hello{% endwith_glossarist_context %}")
    end.not_to raise_error
  end

  it "renders block with context variable set" do
    v2_path = File.expand_path("../../../../fixtures/dataset-glossarist-v2",
                               __dir__)
    template = <<~LIQUID
      {% with_glossarist_context concepts=#{v2_path} %}
      {{ concepts.size }}
      {% endwith_glossarist_context %}
    LIQUID
    rendered = Liquid::Template.parse(template).render
    expect(rendered.strip).to match(/\d+/)
  end

  it "applies filters to the loaded concepts" do
    v2_path = File.expand_path("../../../../fixtures/dataset-glossarist-v2",
                               __dir__)
    template = <<~LIQUID
      {% with_glossarist_context concepts=#{v2_path}; domain=foo %}
      {% for c in concepts %}{{ c.default_designation }},{% endfor %}
      {% endwith_glossarist_context %}
    LIQUID
    rendered = Liquid::Template.parse(template).render
    designations = rendered.strip.split(",").map(&:strip).reject(&:empty?)
    expect(designations).to include("entity")
    expect(designations).not_to include("biological entity")
  end

  it "exposes ManagedConceptDrop instances" do
    v2_path = File.expand_path("../../../../fixtures/dataset-glossarist-v2",
                               __dir__)
    template = <<~LIQUID
      {% with_glossarist_context concepts=#{v2_path} %}
      {% for c in concepts %}{{ c.data.id }},{% endfor %}
      {% endwith_glossarist_context %}
    LIQUID
    rendered = Liquid::Template.parse(template).render
    expect(rendered.strip).to include("3.1.1.1")
  end
end
