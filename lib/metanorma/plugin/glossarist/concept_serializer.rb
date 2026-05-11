# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptSerializer
        def initialize(concept)
          @concept = concept
        end

        def to_h
          { "data" => concept_data_hash }
        end

        private

        def concept_data_hash
          {
            "id" => @concept.data.id,
            "identifier" => @concept.data.id,
            "localized_concepts" => @concept.data.localized_concepts,
            "groups" => @concept.data.groups.to_a,
            "localizations" => localizations_hash,
            "sources" => sources_to_h(@concept.data.sources),
          }.compact
        end

        def localizations_hash
          @concept.localizations.to_h do |l10n|
            [l10n.language_code, localized_concept_hash(l10n)]
          end
        end

        def localized_concept_hash(l10n)
          {
            "data" => localized_concept_data_hash(l10n),
            "classification" => l10n.classification,
            "review_type" => l10n.review_type,
          }.compact
        end

        def localized_concept_data_hash(l10n)
          {
            "terms" => l10n.terms.map { |t| designation_to_h(t) },
            "definition" => definitions_to_h(l10n.definition),
            "examples" => definitions_to_h(l10n.examples),
            "notes" => definitions_to_h(l10n.notes),
            "sources" => sources_to_h(l10n.sources),
            "language_code" => l10n.language_code,
            "entry_status" => l10n.entry_status,
          }.compact
        end

        def designation_to_h(designation)
          {
            "type" => designation.type,
            "designation" => designation.designation,
            "normative_status" => designation.normative_status,
            "geographical_area" => designation.geographical_area,
          }.compact
        end

        def definitions_to_h(definitions)
          definitions.map do |d|
            { "content" => d.content,
              "sources" => sources_to_h(d.sources) }.compact
          end
        end

        def sources_to_h(sources)
          return [] unless sources

          sources.map do |source|
            {
              "type" => source.type,
              "origin" => citation_to_h(source.origin),
              "modification" => source.modification,
            }.compact
          end
        end

        def citation_to_h(citation)
          return nil unless citation

          hash = {}
          hash["text"] = citation.text if citation.text && !citation.text.empty?
          hash["ref"] = citation.text if citation.text && !citation.text.empty?

          if citation.locality
            hash["locality"] = {
              "type" => citation.locality.type,
              "reference_from" => citation.locality.reference_from,
            }
            hash["clause"] = citation.locality.reference_from
          end

          hash["link"] = citation.link if citation.link
          hash
        end
      end
    end
  end
end
