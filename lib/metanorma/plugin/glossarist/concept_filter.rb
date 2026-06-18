# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Filters a concept collection by lang, domain, section, tag, generic
      # field paths, and sort_by. Composable: every filter narrows the
      # collection independently.
      #
      # Section filtering supports cascading membership: a concept in
      # section "3.1.1" is also a member of "3.1" and "3" via transitive
      # ancestor traversal. This requires a DatasetRegister collaborator
      # (passed via `#apply`'s second arg) when section filtering is used.
      class ConceptFilter
        COLLECTION_FILTERS = %w[lang domain group section tag sort_by].freeze
        SORT_LAST = ["￿"].freeze
        SECTION_REF_TYPE = "section"
        DOMAIN_REF_TYPE = "domain"

        def initialize(filters)
          @filters = filters || {}
          @resolver = ConceptPathResolver.new
        end

        # Applies all configured filters in canonical order.
        # @param collection [Enumerable<ManagedConcept>]
        # @param register [Glossarist::DatasetRegister, nil] required for
        #   cascading section filtering; ignored otherwise.
        # @return [Array<ManagedConcept>]
        def apply(collection, register: nil)
          result = collection.to_a
          result = filter_by_lang(result) if @filters.key?("lang")
          if @filters.key?("domain") || @filters.key?("group")
            result = filter_by_domain(result)
          end
          if @filters.key?("section")
            result = filter_by_section(result,
                                       register)
          end
          result = filter_by_tag(result) if @filters.key?("tag")
          result = filter_by_field(result) if field_filters?
          result = sort(result) if @filters.key?("sort_by")
          result
        end

        private

        def field_filters?
          (@filters.keys - COLLECTION_FILTERS).any?
        end

        def filter_by_lang(collection)
          lang = @filters["lang"]
          collection.reject { |c| c.localization(lang).nil? }
        end

        def filter_by_domain(collection)
          domain_id = @filters["domain"] || @filters["group"]
          collection.select do |concept|
            domain_ids(concept).include?(domain_id)
          end
        end

        def filter_by_tag(collection)
          tag = @filters["tag"]
          collection.select { |c| c.data.tags&.include?(tag) }
        end

        def filter_by_section(collection, register)
          target_id = @filters["section"]
          cascade = SectionCascade.new(register)
          collection.select do |concept|
            cascade.member?(concept, target_id)
          end
        end

        def domain_ids(concept)
          Array(concept.data&.domains)
            .select { |d| d.ref_type == DOMAIN_REF_TYPE }
            .filter_map(&:concept_id)
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
          path, value, start_with = field_filter_spec
          start_with_match_value = extract_start_with_value(path, value)
          path, match_value = if start_with_match_value
                                [start_with_match_value[:path],
                                 start_with_match_value[:value]]
                              else
                                [path, value]
                              end

          collection.select do |concept|
            actual = @resolver.resolve(concept, path)
            start_with ? actual&.start_with?(match_value) : actual == value
          end
        end

        def field_filter_spec
          path = (@filters.keys - COLLECTION_FILTERS).first
          start_with = path.include?(".start_with(")
          [path, @filters[path], start_with]
        end

        def extract_start_with_value(path, _value)
          match = path.match(/^([^.]+(?:\.[^.]+)*)\.start_with\(([^)]+)\)$/)
          return nil unless match

          { path: match[1], value: match[2] }
        end
      end
    end
  end
end
