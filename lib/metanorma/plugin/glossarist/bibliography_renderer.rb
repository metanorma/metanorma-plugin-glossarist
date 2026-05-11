# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class BibliographyRenderer
        def initialize(rendered_bibliographies = {})
          @rendered = rendered_bibliographies
        end

        def render_entry(concept)
          l10n = concept.localization("eng")
          return nil unless l10n

          sources = l10n.sources
          return nil if sources.nil? || sources.empty?

          lines = sources.filter_map do |source|
            ref = source.origin&.text
            next if ref.nil? || ref.empty?
            next if @rendered.key?(ref)

            @rendered[ref] = ref.gsub(%r{[ /:]}, "_")
            "* [[[#{@rendered[ref]},#{ref}]]]"
          end

          result = lines.compact.join("\n")
          result.empty? ? nil : result
        end

        def render_all(concepts)
          entries = concepts.filter_map { |concept| render_entry(concept) }
          entries.sort.join("\n")
        end
      end
    end
  end
end
