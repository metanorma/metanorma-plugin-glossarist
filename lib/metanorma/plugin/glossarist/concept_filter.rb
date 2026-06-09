# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptFilter
        COLLECTION_FILTERS = %w[lang domain group section tag sort_by].freeze
        SORT_LAST = ["￿"].freeze

        def initialize(filters)
          @filters = filters || {}
          @resolver = ConceptPathResolver.new
        end

        def apply(collection)
          result = collection
          result = filter_by_lang(result) if @filters.key?("lang")
          if @filters.key?("domain") || @filters.key?("group")
            result = filter_by_domain(result)
          end
          result = filter_by_section(result) if @filters.key?("section")
          result = filter_by_tag(result) if @filters.key?("tag")
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

        def filter_by_domain(collection)
          domain = @filters["domain"] || @filters["group"]
          collection.select do |c|
            c.data.domains&.any? { |d| d.concept_id == domain }
          end
        end

        def filter_by_tag(collection)
          tag = @filters["tag"]
          collection.select do |c|
            c.data.tags&.include?(tag)
          end
        end

        def filter_by_section(collection)
          section_id = @filters["section"]
          collection.select do |c|
            c.data.domains&.any? { |d| d.concept_id == "section-#{section_id}" }
          end
        end

        def sort(collection)
          field = @filters["sort_by"]
          return collection unless field

          case field
          when "term", "default_designation"
            collection.sort_by { |c| c.default_designation.to_s.downcase }
          else
            collection.sort_by { |c| sort_key(c, field) }
          end
        end

        def sort_key(concept, field)
          value = @resolver.resolve(concept, field)
          value.nil? ? SORT_LAST : natural_sort_key(value.to_s)
        end

        def natural_sort_key(str)
          str.scan(/(\d+)|(\D+)/)
            .map { |num, txt| num ? num.to_i : txt.downcase }
        end

        def filter_by_field(collection)
          path = field_filter_key
          value = @filters[path]

          start_with = path.include?(".start_with(")
          path, match_value = extract_start_with(path, value, start_with)

          collection.select do |concept|
            actual = @resolver.resolve(concept, path)
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
      end
    end
  end
end
