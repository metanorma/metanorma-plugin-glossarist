# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # A single field-based filter specification: a path through the concept
      # graph, a matcher kind, and the comparison value.
      #
      # FieldFilter is the structured representation behind ConceptFilter's
      # field-filter DSL. ConceptFilter parses the legacy pseudo-syntax
      # (e.g. +key.start_with(pattern)=ignored+) into FieldFilter instances;
      # future syntaxes (regex, contains) only need a new matcher symbol.
      FieldFilter = Struct.new(:path, :matcher, :value, keyword_init: true) do
        START_WITH_SUFFIX = /\.start_with\(([^)]+)\)\z/

        # Parses a single filter hash entry (path-key, optional value) into
        # a FieldFilter. Two shapes are recognized:
        #
        #   - "data.path" => "value" → matcher :eq, value "value"
        #   - "data.path.start_with(pattern)" => _ → matcher :start_with,
        #     value "pattern" (the hash value is ignored)
        #
        # @param path [String] raw filter key
        # @param raw_value [String, nil] raw filter value
        # @return [FieldFilter]
        def self.from_options_entry(path, raw_value)
          if (match = path.match(START_WITH_SUFFIX))
            FieldFilter.new(
              path: match.pre_match,
              matcher: :start_with,
              value: match[1],
            )
          else
            FieldFilter.new(path: path, matcher: :eq, value: raw_value)
          end
        end

        # Applies the filter to a single concept via the given path resolver.
        # @param resolver [ConceptPathResolver]
        # @param concept [ManagedConcept]
        def match?(resolver, concept)
          actual = resolver.resolve(concept, path)
          case matcher
          when :start_with then actual&.start_with?(value.to_s)
          else actual == value
          end
        end
      end
    end
  end
end
