# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Resolves whether a concept is a member of a target section, including
      # via cascading ancestor traversal (concept-model: gloss:hasChildSection
      # is owl:TransitiveProperty — a concept in "3.1.1" is also in "3.1"
      # and "3").
      #
      # Resolution order:
      #   1. DatasetRegister#concept_section_ids(concept) when register is
      #      available — the canonical V3 path with full cascading.
      #   2. Direct ConceptReference domain match (ref_type: "section") —
      #      legacy/fallback when no register is provided. Still applies
      #      cascading by walking the register's section tree if available.
      class SectionCascade
        SECTION_REF_TYPE = "section"

        def initialize(register = nil)
          @register = register
        end

        # True if the concept belongs to target_id or any of target_id's
        # descendant sections (cascading membership).
        def member?(concept, target_id)
          return false unless concept&.data

          if @register
            cascade_member?(concept, target_id)
          else
            local_member?(concept, target_id)
          end
        end

        private

        def cascade_member?(concept, target_id)
          concept_ids = @register.concept_section_ids(concept)
          return false if concept_ids.nil? || concept_ids.empty?

          concept_ids.any?(target_id)
        end

        def local_member?(concept, target_id)
          Array(concept.data.domains).any? do |domain|
            domain.ref_type == SECTION_REF_TYPE &&
              (domain.concept_id == target_id ||
               descendant_of?(domain.concept_id, target_id))
          end
        end

        def descendant_of?(child_id, ancestor_id)
          return false unless @register

          ancestors = @register.section_ancestor_ids(child_id)
          ancestors.include?(ancestor_id)
        end
      end
    end
  end
end
