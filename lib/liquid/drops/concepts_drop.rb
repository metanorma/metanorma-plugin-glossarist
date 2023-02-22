# frozen_string_literal: true

module Liquid
  module Drops
    class ConceptsDrop < Liquid::Drop
      # rubocop:disable Lint/MissingSuper
      NON_LANGUAGE_FIELDS = %w[term termid].freeze

      def initialize(managed_concept_collection, filters = {})
        @concepts_collection = managed_concept_collection
        @concepts_map = {}

        filtered_concepts(@concepts_collection, filters).each do |concept|
          @concepts_map[concept["term"]] = concept
        end
      end
      # rubocop:enable Lint/MissingSuper

      def concepts
        @concepts_map
      end

      def [](concept_name)
        @concepts_map[concept_name]
      end

      def each(&block)
        @concepts_map.values.each(&block)
      end

      private

      def filtered_concepts(concepts_collection, filters)
        concepts_collection.to_h["managed_concepts"].map do |concept|
          filtered_concept = concept.dup
          filtered_concept.each do |field, concept_hash|
            next if NON_LANGUAGE_FIELDS.include?(field)

            if language_field?(field) && filters['lang'] && !allowed_languages(filters['lang']).include?(field.strip)
              filtered_concept.delete(field)
              next
            end

            filters.each do |name, value|
              next if name == "lang"

              fields = extract_nested_field_names(name)

              if filtered_concept.dig(*fields) != value
                filtered_concept.delete(field)
              end
            end
          end

          if filtered_concept.keys & NON_LANGUAGE_FIELDS == filtered_concept.keys
            nil
          else
            filtered_concept
          end
        end.compact
      end

      def extract_nested_field_names(name)
        name.split(".").map do |field|
          field_name = field.strip

          field_name.match(/^\d+$/) ? field_name.to_i : field_name
        end
      end

      def language_field?(field_name)
        !NON_LANGUAGE_FIELDS.include?(field_name)
      end

      def allowed_languages(languages_string)
        languages_string.split(",").map(&:strip)
      end

      def except(hash, keys)
        dup_hash = hash.dup

        keys.each do |key|
          dup_hash.delete(key)
        end

        dup_hash
      end
    end
  end
end
