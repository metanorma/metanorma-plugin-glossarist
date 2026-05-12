# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class BibliographyRenderer
        def initialize
          @rendered = {}
        end

        def render_entry(concept, lang: "eng")
          l10n = concept.localization(lang)
          return nil unless l10n

          entries = source_entries(l10n)
          warn_unresolved_xrefs(l10n)
          entries.empty? ? nil : entries.sort.join("\n")
        end

        def render_all(concepts, lang: "eng")
          entries = concepts.filter_map { |c| render_entry(c, lang: lang) }
          entries.sort.join("\n")
        end

        private

        def source_entries(l10n)
          sources = l10n.sources
          return [] if sources.nil? || sources.empty?

          sources.filter_map do |source|
            ref = source.origin&.text
            next if ref.nil? || ref.empty?
            next if @rendered.key?(ref)

            anchor = ref.gsub(%r{[ /:]}, "_")
            @rendered[ref] = anchor
            "* [[[#{anchor},#{ref}]]]"
          end
        end

        def warn_unresolved_xrefs(l10n)
          xref_ids = extract_content_xrefs(l10n)
          return if xref_ids.empty?

          xref_ids.each do |ref_id|
            next if @rendered.value?(ref_id)

            warn "[glossarist] unresolved bibliography reference: " \
                 "<<#{ref_id}>> — not defined as a source in the dataset"
          end
        end

        def extract_content_xrefs(l10n)
          parts = []
          l10n.definition&.each { |d| parts << d.content.to_s }
          l10n.notes&.each { |n| parts << n.content.to_s }
          l10n.examples&.each { |e| parts << e.content.to_s }
          return [] if parts.empty?

          Sanitize.extract_xrefs(parts.join(" "))
        end
      end
    end
  end
end
