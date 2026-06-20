# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Renders concepts grouped by section, with cascading membership and
      # configurable sort order.
      #
      # Extracted from DatasetPreprocessor to keep section rendering as a
      # single MECE concern: it owns section → concepts resolution, heading
      # depth, and per-section rendering. Callers retain ownership of the
      # rendered-concept accumulator (passed via the block) so the
      # preprocessor's global state stays in one place.
      class SectionRenderer
        DEFAULT_SORT_BY = "term"

        # @param dataset [Enumerable<ManagedConcept>] the full dataset
        # @param register [Glossarist::DatasetRegister, nil] for cascading
        # @param renderer [TemplateRenderer] concept renderer
        # @param depth [Integer] base heading depth for sections
        # @param options [Hash] :sort_by, :anchor_prefix, :non_verbal
        def initialize(dataset:, register:, renderer:, depth:, **options)
          @dataset = dataset
          @register = register
          @renderer = renderer
          @depth = depth
          @sort_by = options[:sort_by] || DEFAULT_SORT_BY
          @anchor_prefix = options[:anchor_prefix]
          @non_verbal = options[:non_verbal]
        end

        # @param sections [Array<Glossarist::Section>]
        # @yield [Array<ManagedConcept>] concepts matched for each section
        # @return [Array<String>] one rendered block per non-empty section
        def render(sections)
          sections.filter_map do |section|
            concepts = concepts_for(section)
            next if concepts.empty?

            yield concepts if block_given?

            block_for(section, concepts)
          end
        end

        private

        def concepts_for(section)
          filter_options = { "section" => section.id, "sort_by" => @sort_by }
          concepts = ConceptFilter.new(filter_options)
            .apply(@dataset, register: @register)
          concepts.select(&:default_designation)
        end

        def block_for(section, concepts)
          heading = "#{'=' * (@depth + 1)} #{section.name || section.id}"
          body = @renderer.render_concepts(concepts,
                                           depth: @depth + 1,
                                           anchor_prefix: @anchor_prefix,
                                           non_verbal: @non_verbal)
          "#{heading}\n\n#{body}"
        end
      end
    end
  end
end
