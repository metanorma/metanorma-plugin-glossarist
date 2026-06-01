# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptPathResolver
        def initialize(concept)
          @concept = concept
        end

        def resolve(path)
          parts = parse_path(path)
          value = navigate(@concept, parts)
          value.is_a?(String) ? value : value.to_s
        end

        private

        MANAGED_CONCEPT_METHODS = {
          "data" => :data,
          "localizations" => :localizations_via_data,
          "identifier" => :identifier,
          "default_designation" => :default_designation,
          "schema_version" => :schema_version,
          "uuid" => :uuid,
          "tags" => :tags_via_data,
        }.freeze

        MANAGED_CONCEPT_DATA_METHODS = {
          "localizations" => :localizations,
          "localized_concepts" => :localized_concepts,
          "id" => :id,
          "identifier" => :id,
          "tags" => :tags,
          "domains" => :domains,
          "related" => :related,
        }.freeze

        LOCALIZED_CONCEPT_METHODS = {
          "data" => :data,
          "language_code" => :language_code,
          "entry_status" => :entry_status,
        }.freeze

        CONCEPT_DATA_METHODS = {
          "terms" => :terms,
          "definition" => :definition,
          "examples" => :examples,
          "notes" => :notes,
          "sources" => :sources,
          "id" => :id,
          "domain" => :domain,
          "related" => :related,
        }.freeze

        COLLECTION_INDEXABLE = [
          ::Glossarist::Collections::DetailedDefinitionCollection,
          ::Glossarist::Collections::ConceptSourceCollection,
          ::Glossarist::Collections::DesignationCollection,
        ].freeze

        def parse_path(path)
          path.split(".").flat_map do |segment|
            if segment.include?("[")
              parse_indexed_segment(segment)
            else
              [segment]
            end
          end
        end

        def parse_indexed_segment(segment)
          field, index_part = segment.split("[", 2)
          index = index_part&.delete("]'\"")
          if index.match?(/\A\d+\z/)
            [field, index.to_i]
          else
            [field, index]
          end
        end

        def navigate(obj, parts)
          parts.reduce(obj) do |current, key|
            return nil if current.nil?
            access(current, key)
          end
        end

        def access(obj, key)
          case key
          when String then access_string_key(obj, key)
          when Integer then access_index(obj, key)
          end
        end

        def access_string_key(obj, key)
          case obj
          when ::Glossarist::ManagedConcept
            resolve_managed_concept(obj, key)
          when ::Glossarist::ManagedConceptData
            resolve_managed_concept_data(obj, key)
          when ::Glossarist::LocalizedConcept
            resolve_localized_concept(obj, key)
          when ::Glossarist::ConceptData
            resolve_concept_data(obj, key)
          when ::Glossarist::Collections::LocalizationCollection
            obj.find_by(:language_code, key)
          when Hash
            obj[key] || obj[key.to_s]
          when Array
            nil
          else
            resolve_generic(obj, key)
          end
        end

        def resolve_managed_concept(concept, key)
          method = MANAGED_CONCEPT_METHODS[key]
          return nil unless method

          case method
          when :localizations_via_data then concept.data.localizations
          when :tags_via_data then concept.data.tags
          else concept.public_send(method)
          end
        end

        def resolve_managed_concept_data(data, key)
          method = MANAGED_CONCEPT_DATA_METHODS[key]
          method ? data.public_send(method) : nil
        end

        def resolve_localized_concept(l10n, key)
          method = LOCALIZED_CONCEPT_METHODS[key]
          method ? l10n.public_send(method) : nil
        end

        def resolve_concept_data(data, key)
          method = CONCEPT_DATA_METHODS[key]
          method ? data.public_send(method) : nil
        end

        def resolve_generic(obj, key)
          return nil unless obj.is_a?(::Lutaml::Model::Serializable)
          obj.class.attributes.key?(key.to_sym) ? obj.public_send(key.to_sym) : nil
        end

        def access_index(obj, index)
          case obj
          when Array then obj[index]
          when *COLLECTION_INDEXABLE then obj[index]
          else nil
          end
        end
      end
    end
  end
end
