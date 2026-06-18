# frozen_string_literal: true

require "set"

module Metanorma
  module Plugin
    module Glossarist
      # Renders iev termbank and dataset bibliography entries as AsciiDoc
      # bibliography items for rendered concepts.
      #
      # Bibliography lookups go through the typed Glossarist::BibliographyData
      # model — entries are matched by `id` and read via BibliographyEntry
      # accessors (#reference, #title, #link).
      class BibliographyRenderer
        IEV_ENTRY = "* [[[ievtermbank,IEV]]], _IEV: Electropedia_"
        IEV_ANCHOR = "ievtermbank"

        def initialize(existing_anchors: [], bibliography: nil)
          @rendered = {}
          @existing_anchors = Set.new(existing_anchors)
          @bibliography = bibliography
        end

        def render_entry(concept, lang: "eng")
          l10n = concept.localization(lang)
          return nil unless l10n

          entries = source_entries(l10n)
          entries.concat(xref_entries(l10n))
          entries.empty? ? nil : entries.sort.join("\n")
        end

        def render_all(concepts, lang: "eng")
          all_entries = concepts.filter_map do |concept|
            l10n = concept.localization(lang)
            next unless l10n

            source_entries(l10n)
          end.flatten

          xref = concepts.filter_map do |concept|
            l10n = concept.localization(lang)
            next unless l10n

            xref_entries(l10n)
          end.flatten

          all_entries.concat(xref)
          all_entries.sort.join("\n")
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
            next if @existing_anchors.include?(anchor)

            @rendered[ref] = anchor

            if anchor == IEV_ANCHOR
              IEV_ENTRY
            else
              format_entry(anchor, ref)
            end
          end
        end

        def xref_entries(l10n)
          xref_ids = extract_content_xrefs(l10n)
          return [] if xref_ids.empty?

          xref_ids.filter_map do |ref_id|
            next if @rendered.value?(ref_id)
            next if @existing_anchors.include?(ref_id)
            next unless bibliography_entry(ref_id)

            @rendered[ref_id] = ref_id
            format_entry(ref_id, ref_id)
          end
        end

        def format_entry(anchor, ref)
          entry = bibliography_entry(ref)
          return "* [[[#{anchor},#{ref}]]]" unless entry

          display_ref = entry.reference || ref
          parts = ["* [[[#{anchor},#{display_ref}]]]"]
          parts << ", _#{entry.title}_" if entry.title
          parts << ". Available at: #{entry.link} " if entry.link
          parts.join
        end

        def bibliography_entry(ref_id)
          return nil unless @bibliography

          @bibliography.find(ref_id)
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
