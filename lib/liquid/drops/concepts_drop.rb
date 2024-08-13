# frozen_string_literal: true

module Liquid
  module Drops
    class ConceptsDrop < Liquid::Drop
      NON_LANGUAGE_FIELDS = %w[identifier localized_concepts groups term].freeze

      # rubocop:disable Lint/MissingSuper
      def initialize(managed_concept_collection, filters = {})
        @concepts_collection = managed_concept_collection
        @concepts_map = {}

        filtered_concepts(@concepts_collection, filters).each do |concept|
          @concepts_map[concept["term"]] = sanitize_concept(concept)
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

      def sanitize_concept(concept)
        concept["localized_concepts"].each do |lang, _localized_concept_uuid|
          localized_concept = concept[lang]
          next unless localized_concept

          localized_concept["definition"] = localized_concept["definition"].map do |definition|
            { "content" => sanitize_references(definition["content"]) }
          end

          localized_concept["examples"] = localized_concept["examples"].map do |example|
            { "content" => sanitize_references(example["content"]) }
          end

          localized_concept["notes"] = localized_concept["notes"].map do |note|
            { "content" => sanitize_references(note["content"]) }
          end
        end

        concept
      end

      def sanitize_references(str)
        str.gsub(/\{\{([^,]*),([^\}]*)\}\}/) do |match|
          "{{#{Metanorma::Utils.to_ncname(Regexp.last_match[1])},#{Regexp.last_match[2]}}}"
        end
      end

      def filtered_concepts(concepts_collection, filters)
        concept_filters = filters.dup
        language_filter = concept_filters.delete("lang")
        sort_filter = concept_filters.delete("sort_by")
        group_filter = concept_filters.delete("group")

        concepts = concepts_collection.map do |concept|
          filtered_concept = concept.to_h["data"]
          filtered_concept["term"] = concept.default_designation

          filtered_concept = filtered_concept.merge(
            extract_localized_concepts(concept, language_filter),
          )

          if retain_concept?(filtered_concept, concept_filters)
            filtered_concept
          end
        end.compact

        apply_group_filter(concepts, group_filter)
        apply_sort_filter(concepts, sort_filter)
      end

      def extract_localized_concepts(concept, languages)
        localized_concepts = {}

        if !languages || languages.empty?
          concept.localized_concepts.each do |lang, _localized_concept_uuid|
            localized_concepts[lang] = concept.localizations[lang].to_h["data"]
          end
        else
          languages.split(",").each do |lang|
            localization = concept.localizations[lang]&.to_h&.dig("data") and
              localized_concepts[lang] = localization
          end
        end

        localized_concepts
      end

      def retain_concept?(filtered_concept, concept_filters)
        concept_filters.each do |name, value|
          fields = extract_nested_field_names(name)
          if fields.last.start_with?("start_with")
            value = fields.last.gsub(/start_with\(([^\)]*)\)/, '\1')
            fields = fields[0..-2]
            filtered_concept.dig(*fields).start_with?(value) or
              return false
          elsif filtered_concept.dig(*fields) != value
            return false
          end
        end

        filtered_concept.keys & NON_LANGUAGE_FIELDS != filtered_concept.keys
      end

      def apply_sort_filter(concepts, sort_by)
        return concepts unless sort_by

        concepts.sort_by do |concept|
          concept.dig(*extract_nested_field_names(sort_by))
        end
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

          /^\d+$/.match?(field_name) ? field_name.to_i : field_name
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
