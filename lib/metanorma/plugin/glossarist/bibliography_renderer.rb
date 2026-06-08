# frozen_string_literal: true

require "set"

module Metanorma
  module Plugin
    module Glossarist
      class BibliographyRenderer
        IEV_ENTRY = "* [[[ievtermbank,IEV]]], _IEV: Electropedia_"
        IEV_ANCHOR = "ievtermbank"

        def initialize(existing_anchors: [], bibliography_data: {})
          @rendered = {}
          @existing_anchors = Set.new(existing_anchors)
          @bibliography_data = bibliography_data
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

          xref_entries = concepts.filter_map do |concept|
            l10n = concept.localization(lang)
            next unless l10n

            xref_entries(l10n)
          end.flatten

          all_entries.concat(xref_entries)

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
            next unless @bibliography_data.key?(ref_id)

            @bibliography_data[ref_id]
            anchor = ref_id
            @rendered[ref_id] = anchor

            format_entry(anchor, ref_id)
          end
        end

        def format_entry(anchor, ref)
          bib = @bibliography_data[ref]
          return "* [[[#{anchor},#{ref}]]]" unless bib

          display_ref = bib["reference"] || ref
          parts = ["* [[[#{anchor},#{display_ref}]]]"]
          parts << ", _#{bib['title']}_" if bib["title"]
          parts << ". Available at: #{bib['link']} " if bib["link"]
          parts.join
        end

        def extract_content_xrefs(l10n)
          parts = []
          l10n.definition&.each { |d| parts << d.content.to_s }
          l10n.notes&.each { |n| parts << n.content.to_s }
          l10n.examples&.each { |e| parts << e.content.to_s }
          if l10n.data.class.method_defined?(:detailed_definition_fields)
            l10n.data.class.detailed_definition_fields.each do |field|
              next if %i[definition notes examples].include?(field)

              l10n.data.send(field)&.each { |d| parts << d.content.to_s }
            end
          end
          return [] if parts.empty?

          Sanitize.extract_xrefs(parts.join(" "))
        end
      end
    end
  end
end
