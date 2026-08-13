# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Extracts bibliography-citable mention IDs from concept text using
      # +Glossarist::ReferenceExtractor+ as the single canonical parser.
      #
      # Bibliography relevance = +BibliographicReference+ (from +{{bib:id}}+
      # mentions) and +ConceptReference+ instances whose +#cite?+ is true
      # (from +{{cite:id}}+ mentions). Other mention kinds
      # (fig/table/formula/urn) reference assets or concepts, not
      # bibliography entries.
      class MentionExtractor
        def initialize(text)
          @text = text
        end

        def bibliography_ids
          refs = ::Glossarist::ReferenceExtractor.new
            .extract_from_text(@text.to_s)
          refs.filter_map { |ref| bibliography_id(ref) }.uniq
        end

        private

        def bibliography_id(ref)
          case ref
          when ::Glossarist::BibliographicReference
            ref.anchor
          when ::Glossarist::ConceptReference
            ref.concept_id if ref.cite?
          end
        end
      end
    end
  end
end
