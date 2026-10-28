# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::SectionMembership do
  let(:register) do
    Glossarist::DatasetRegister.new(
      sections: [
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
      ],
    )
  end

  def concept_with_domain(concept_id:, domain_id: nil, id: nil)
    Glossarist::ManagedConcept.new(
      uuid: id || concept_id,
      data: Glossarist::ManagedConceptData.new(
        id: id || concept_id,
        domains: domain_id ? [Glossarist::ConceptReference.section(domain_id)] : [],
      ),
    )
  end

  describe "#section_ids" do
    it "normalises a section- prefixed domain to the register section" do
      concept = concept_with_domain(concept_id: "action_schema.Action",
                                    domain_id: "section-action_schema")
      ids = described_class.new(register).section_ids(concept)
      expect(ids).to eq(%w[action_schema resources])
    end

    it "keeps a bare domain id unchanged" do
      concept = concept_with_domain(concept_id: "action_schema.Action",
                                    domain_id: "action_schema")
      ids = described_class.new(register).section_ids(concept)
      expect(ids).to eq(%w[action_schema resources])
    end

    it "derives the section from the concept id when it has no domain" do
      concept = concept_with_domain(concept_id: "action_schema-1")
      ids = described_class.new(register).section_ids(concept)
      expect(ids).to eq(%w[action_schema resources])
    end

    it "returns no sections when the concept matches no register section" do
      concept = concept_with_domain(concept_id: "unmatched")
      expect(described_class.new(register).section_ids(concept)).to eq([])
    end

    it "returns no sections without a register" do
      concept = concept_with_domain(concept_id: "action_schema.Action",
                                    domain_id: "section-action_schema")
      expect(described_class.new(nil).section_ids(concept)).to eq([])
    end
  end

  describe "#direct_section_ids" do
    it "normalises a section- prefixed domain and omits ancestors" do
      concept = concept_with_domain(concept_id: "action_schema.Action",
                                    domain_id: "section-action_schema")
      ids = described_class.new(register).direct_section_ids(concept)
      expect(ids).to eq(["action_schema"])
    end

    it "keeps a bare domain id unchanged" do
      concept = concept_with_domain(concept_id: "action_schema.Action",
                                    domain_id: "action_schema")
      ids = described_class.new(register).direct_section_ids(concept)
      expect(ids).to eq(["action_schema"])
    end

    it "returns no ids when the concept declares no section domain" do
      concept = concept_with_domain(concept_id: "action_schema-1")
      expect(described_class.new(register).direct_section_ids(concept))
        .to eq([])
    end

    it "returns no ids without a register" do
      concept = concept_with_domain(concept_id: "action_schema.Action",
                                    domain_id: "section-action_schema")
      expect(described_class.new(nil).direct_section_ids(concept)).to eq([])
    end
  end
end
