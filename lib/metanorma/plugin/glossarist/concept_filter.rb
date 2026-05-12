# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptFilter
        COLLECTION_FILTERS = %w[lang group sort_by].freeze

        def initialize(filters)
          @filters = filters || {}
        end

        def apply(collection)
          result = collection
          result = filter_by_lang(result) if @filters.key?("lang")
          result = filter_by_group(result) if @filters.key?("group")
          result = filter_by_field(result) if field_filter?
          result = sort(result) if @filters.key?("sort_by")
          result
        end

        private

        def field_filter?
          (@filters.keys - COLLECTION_FILTERS).any?
        end

        def field_filter_key
          (@filters.keys - COLLECTION_FILTERS).first
        end

        def filter_by_lang(collection)
          lang = @filters["lang"]
          collection.reject { |c| c.localization(lang).nil? }
        end

        def filter_by_group(collection)
          group = @filters["group"]
          collection.select { |c| c.data.groups&.include?(group) }
        end

        def sort(collection)
          field = @filters["sort_by"]
          return collection unless field

          case field
          when "term", "default_designation"
            collection.sort_by { |c| c.default_designation.to_s.downcase }
          else
            parts = parse_path(field)
            collection.sort_by { |c| sort_key(c, parts) }
          end
        end

        def sort_key(concept, parts)
          hash = ConceptSerializer.new(concept).to_h
          value = dig_path(hash, parts)
          value.nil? ? SORT_LAST : natural_sort_key(value.to_s)
        end

        SORT_LAST = ["￿"].freeze

        def natural_sort_key(str)
          str.scan(/(\d+)|(\D+)/).map { |num, txt| num ? num.to_i : txt.downcase }
        end

        def filter_by_field(collection)
          path = field_filter_key
          value = @filters[path]

          start_with = path.include?(".start_with(")
          path, match_value = extract_start_with(path, value, start_with)

          parts = parse_path(path)
          collection.select do |concept|
            hash = ConceptSerializer.new(concept).to_h
            actual = dig_path(hash, parts)
            if start_with
              actual&.start_with?(match_value)
            else
              actual == value
            end
          end
        end

        def extract_start_with(path, value, start_with)
          return [path, value] unless start_with

          match = path.match(/^([^.]+(?:\.[^.]+)*)\.start_with\(([^)]+)\)$/)
          return [path, value] unless match

          [match[1], match[2]]
        end

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

        def dig_path(hash, parts)
          parts.reduce(hash) do |current, key|
            case current
            when Hash
              current[key] || current[key.to_s]
            when Array
              key.is_a?(Integer) ? current[key] : nil
            end
          end
        end
      end
    end
  end
end
