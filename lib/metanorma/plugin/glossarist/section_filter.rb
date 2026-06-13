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
        # @return [Array<Glossarist::Section>]
        def apply(sections)
          sections.select { |s| matches?(s) }
        end

        private

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
