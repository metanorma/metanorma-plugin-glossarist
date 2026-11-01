# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metanorma::Plugin::Glossarist::DatasetRegistry do
  let(:registry) { described_class.new }
  let(:v2_dataset) do
    File.expand_path("../../../fixtures/dataset-glossarist-v2", __dir__)
  end
  let(:v3_dataset) do
    File.expand_path("../../../fixtures/dataset-glossarist-v3", __dir__)
  end

  after do
    described_class.clear_shared_stores
    ENV.delete(described_class::SHARED_STORE_ENV)
  end

  it "keeps per-registry loads distinct while the gate is unset" do
    first = described_class.new.concepts_at(v2_dataset)
    second = described_class.new.concepts_at(v2_dataset)
    expect(second.map(&:id)).to eq(first.map(&:id))
    expect(second).not_to equal(first)
  end

  it "serves one shared concept array across registries when enabled" do
    ENV[described_class::SHARED_STORE_ENV] = "1"
    first = described_class.new.concepts_at(v2_dataset)
    second = described_class.new.concepts_at(v2_dataset)
    expect(second).to equal(first)
  end

  it "shares the loaded store, not only the concept array" do
    ENV[described_class::SHARED_STORE_ENV] = "1"
    first = described_class.new
    first.register(nil, "ds:#{v2_dataset}")
    second = described_class.new
    second.register(nil, "ds:#{v2_dataset}")
    # one shared GlossaryStore answers both registries' non-verbal
    # accessors, so the memoized figures array is the very same object
    expect(first.figures_for("ds")).to equal(second.figures_for("ds"))
  end

  it "ignores the gate when it is empty or zero" do
    ["0", ""].each do |v|
      ENV[described_class::SHARED_STORE_ENV] = v
      first = described_class.new.concepts_at(v2_dataset)
      second = described_class.new.concepts_at(v2_dataset)
      expect(second).not_to equal(first)
    end
  end

  it "keys entries by dataset path" do
    ENV[described_class::SHARED_STORE_ENV] = "1"
    v2 = described_class.new.concepts_at(v2_dataset)
    v3 = described_class.new.concepts_at(v3_dataset)
    expect(v2).not_to equal(v3)
    expect(described_class.new.concepts_at(v2_dataset)).to equal(v2)
  end

  it "drops every entry on clear_shared_stores" do
    ENV[described_class::SHARED_STORE_ENV] = "1"
    first = described_class.new.concepts_at(v2_dataset)
    described_class.clear_shared_stores
    second = described_class.new.concepts_at(v2_dataset)
    expect(second).not_to equal(first)
    expect(second.map(&:id)).to eq(first.map(&:id))
  end
end
