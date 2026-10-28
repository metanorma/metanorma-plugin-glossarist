# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Filters an array of Glossarist::Section objects by include/exclude patterns.
      #
      # Pattern matching uses *substring* matching against section IDs
      # (e.g., pattern "3" matches sections with IDs "3", "3.1", "34").
      # For the common _arm/_mim filtering, use patterns like "_arm" and "_mim"
      # which are specific enough to avoid false positives.
      #
      # A hierarchical register groups its schemas under structural category
      # sections (resources, modules, AP publications). When the caller
      # supplies the IDs of sections that own concepts directly, structural
      # sections are descended into so filters apply to the schemas; a
      # section that owns concepts is kept whole, because its descendants
      # cascade into it and rendering both would duplicate them. A flat
      # register is unaffected.
      #
      # @example Exclude _arm and _mim sections
      #   SectionFilter.new(exclude: ["_arm", "_mim"]).apply(sections)
      #
      # @example Include only _arm sections
      #   SectionFilter.new(include: ["_arm"]).apply(sections)
      class SectionFilter
        # @param exclude [Array<String>] substring patterns; sections whose ID
        #   contains any of these are removed
        # @param include [Array<String>] substring patterns; only sections whose
        #   ID contains at least one of these are kept (empty = include all)
        def initialize(exclude: [], include: [])
          @exclude = exclude.reject(&:empty?)
          @include = include.reject(&:empty?)
        end

        # @param sections [Array<Glossarist::Section>]
        # @param populated [Set<String>, nil] IDs of sections that own
        #   concepts directly; nil filters the sections as given
        # @return [Array<Glossarist::Section>] matching sections
        def apply(sections, populated: nil)
          candidates = populated ? content_sections(sections, populated) : sections
          candidates.select { |s| matches?(s) }
        end

        private

        def content_sections(sections, populated)
          Array(sections).flat_map do |section|
            children = Array(section.children)
            if children.empty? || populated.include?(section.id)
              [section]
            else
              content_sections(children, populated)
            end
          end
        end

        def matches?(section)
          !excluded?(section) && included?(section)
        end

        def excluded?(section)
          @exclude.any? { |p| section.id.include?(p) }
        end

        def included?(section)
          @include.empty? || @include.any? { |p| section.id.include?(p) }
        end
      end
    end
  end
end
