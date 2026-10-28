# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Resolves the register section IDs a concept belongs to, including
      # cascading ancestors.
      #
      # Vocabulary extraction records section membership as
      # `concept_id: section-<id>`, while register sections carry the bare
      # `<id>`. Normalising before the ancestor lookup is required: a
      # prefixed ID is not a node in the section tree, so cascading would
      # otherwise find nothing.
      class SectionMembership
        SECTION_ID_PREFIX = "section-"
        SECTION_REF_TYPE = "section"

        def initialize(register)
          @register = register
        end

        # @param concept [Glossarist::ManagedConcept]
        # @return [Array<String>] section IDs, child-first then ancestors
        def section_ids(concept)
          return [] unless @register

          normalized_ids(concept).flat_map do |id|
            [id] + @register.section_ancestor_ids(id)
          end.uniq
        end

        # Section IDs the concept declares directly, without ancestors.
        # Used to tell a section that owns concepts from a structural
        # section that only groups its children.
        #
        # @param concept [Glossarist::ManagedConcept]
        # @return [Array<String>]
        def direct_section_ids(concept)
          return [] unless @register

          Array(concept&.data&.domains)
            .select { |domain| domain.ref_type == SECTION_REF_TYPE }
            .filter_map { |domain| normalize(domain.concept_id) }
            .uniq
        end

        private

        def normalized_ids(concept)
          Array(@register.concept_section_ids(concept))
            .map { |id| normalize(id) }
            .uniq
        end

        def normalize(id)
          id&.delete_prefix(SECTION_ID_PREFIX)
        end
      end
    end
  end
end
