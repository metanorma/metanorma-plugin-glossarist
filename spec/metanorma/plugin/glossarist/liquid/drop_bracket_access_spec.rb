# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::PolyfillIndexedAccess do
  describe ".apply!" do
    it "includes Lutaml::Model::Liquid::IndexedAccess into glossarist collections" do
      described_class.apply!
      expect(Glossarist::Collections::LocalizationCollection)
        .to include(::Lutaml::Model::Liquid::IndexedAccess)
      expect(Glossarist::Collections::DetailedDefinitionCollection)
        .to include(::Lutaml::Model::Liquid::IndexedAccess)
      expect(Glossarist::Collections::ConceptSourceCollection)
        .to include(::Lutaml::Model::Liquid::IndexedAccess)
    end

    it "is idempotent — running twice does not re-include" do
      described_class.apply!
      before = Glossarist::Collections::LocalizationCollection
        .ancestors.length
      described_class.apply!
      after = Glossarist::Collections::LocalizationCollection
        .ancestors.length
      expect(after).to eq(before)
    end
  end
end
