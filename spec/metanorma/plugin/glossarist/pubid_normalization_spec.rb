# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metanorma::Plugin::Glossarist::PubidNormalization do
  include described_class

  it "renders supported pubid forms through pubid's canonical form" do
    expect(normalized_reference("ISO 16634")).to eq("ISO 16634")
    expect(normalized_reference("urn:iso:std:iso:14812")).to eq("ISO 14812")
  end

  it "keeps unsupported forms as written" do
    expect(normalized_reference("not a pubid at all!!")).to eq("not a pubid at all!!")
    expect(normalized_reference("iso/ts 14812:2022")).to eq("iso/ts 14812:2022")
  end

  it "passes nil through" do
    expect(normalized_reference(nil)).to be_nil
  end
end
