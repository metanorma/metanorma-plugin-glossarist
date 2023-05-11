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
        concept_filters = filters.dup
        language_filter = concept_filters.delete('lang')
        sort_filter = concept_filters.delete('sort_by')
        group_filter = concept_filters.delete('group')

        concepts = concepts_collection.to_h["managed_concepts"].map do |concept|
          filtered_concept = concept.dup
          filtered_concept.each do |field, concept_hash|
            next if NON_LANGUAGE_FIELDS.include?(field)

            unless allowed_language?(field, language_filter)
              filtered_concept.delete(field)
              next
            end

            concept_filters.each do |name, value|
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

        apply_group_filter(concepts, group_filter)
        apply_sort_filter(concepts, sort_filter)
      end

      def apply_sort_filter(concepts, sort_by)
        return concepts unless sort_by

        concepts.sort_by { |concept| concept.dig(*extract_nested_field_names(sort_by)) }
      end

      def apply_group_filter(concepts, groups)
        return concepts unless groups

        concepts.select! do |concept|
          groups.split(",").reduce(true) do |pre_result, group|
            pre_result && concept["groups"].include?(group.strip)
          end
        end
      end

      def extract_nested_field_names(name)
        name.split(".").map do |field|
          field_name = field.strip

          field_name.match(/^\d+$/) ? field_name.to_i : field_name
        end
      end

      def allowed_language?(language, lang_filter)
        return false if NON_LANGUAGE_FIELDS.include?(language)
        return true unless lang_filter

        language&.strip == lang_filter&.strip
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
