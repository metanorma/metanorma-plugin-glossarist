# frozen_string_literal: true

require "set"
require_relative "pubid_normalization"

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
        include PubidNormalization

        IEV_ENTRY = "* [[[ievtermbank,IEV]]], _IEV: Electropedia_"
        IEV_ANCHOR = "ievtermbank"

        def initialize(existing_anchors: [], bibliography: nil,
                       documents: nil)
          @rendered = {}
          @existing_anchors = Set.new(existing_anchors)
          @bibliography = bibliography
          @documents = documents
        end

        def render_entry(concept, lang: "eng")
          l10n = concept.localization(lang)
          return nil unless l10n

          entries = source_entries(l10n)
          entries.concat(xref_entries(l10n))
          entries.empty? ? nil : entries.sort.join("\n")
        end

        def render_all(concepts, lang: "eng")
          $stderr.puts "[g108-render_all] concepts=#{concepts.size} first_class=#{concepts.first&.class}"
          bib_mentions = 0
          concepts.each do |c|
            l = c.localization(lang)
            next unless l
            txt = Array(l.notes).map { |n| n.respond_to?(:content) ? n.content : n }.join(" ")
            bib_mentions += 1 if txt.include?("{{bib:")
          end
          $stderr.puts "[g108-render_all] notes_with_bib=#{bib_mentions}"
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
            if document_source?(source)
              document_entry(source)
            else
              legacy_entry(source)
            end
          end
        end

        def document_source?(source)
          !@documents.nil? && !@documents.resolve(source.origin).nil?
        end

        # URN citations of a parent document render one bibliography
        # entry per distinct document (the termsource's bibitemid), not
        # one per concept — the per-concept raw URNs never resolve.
        def document_entry(source)
          doc = @documents&.resolve(source.origin)
          return nil unless doc

          anchor = doc[:anchor]
          return nil if @rendered.key?(anchor)
          return nil if @existing_anchors.include?(anchor)

          @rendered[anchor] = anchor
          format_entry(anchor, doc[:citeas])
        end

        def legacy_entry(source)
          ref = source.origin&.text
          return nil if ref.nil? || ref.empty?
          return nil if @rendered.key?(ref)

          anchor = ref.gsub(%r{[ /:]}, "_")
          return nil if @existing_anchors.include?(anchor)

          @rendered[ref] = anchor

          if anchor == IEV_ANCHOR
            IEV_ENTRY
          elsif dataset_scheme_urn?(ref)
            urn_entry(anchor, ref)
          else
            format_entry(anchor, ref)
          end
        end

        # glossarist#96: a dataset URN citation whose document is not a
        # registered dataset has no document identity. Rendering it as a
        # docid escalates it into a relaton fetch per occurrence; it is
        # rendered literally instead, so it stays linked to its
        # termsource and costs no network.
        def urn_entry(anchor, ref)
          "* [[[#{anchor},nofetch(#{ref})]]]"
        end

        # Citations in the glossarist dataset URN scheme (the scheme
        # DocumentCitations resolves); anything else is a legacy citation
        # of a document identifier and is fetched as written.
        def urn_citation?(ref)
          ref.match?(/\Aurn:/i)
        end

        # ISO URN scheme: the tech segments mark dataset-level
        # identifiers - the glossarist dataset scheme. Those stay nofetch
        # literals, linked to their termsource, costing no relaton fetch
        # (c888a74). Document URNs route through format_entry, where
        # pubid (the SSOT for document identifiers) renders the
        # canonical display form (1650c50).
        def dataset_scheme_urn?(ref)
          urn_citation?(ref) && ref.include?(":tech:")
        end

        def xref_entries(l10n)
          xref_ids = extract_content_xrefs(l10n)
          unless xref_ids.empty?
            $stderr.puts "[g108-xref] ids=#{xref_ids.first(4).inspect} bib=#{!@bibliography.nil?} found=#{xref_ids.filter_map { |i| @bibliography&.find(i) ? 1 : nil }.size} skipped_rendered=#{xref_ids.count { |i| @rendered.value?(i) }} skipped_existing=#{xref_ids.count { |i| @existing_anchors.include?(i) }}"
          end
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
          return "* [[[#{anchor},#{normalized_reference(ref)}]]]" unless entry

          display_ref = normalized_reference(entry.reference || ref)
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
          l10n.data.annotations&.each { |a| parts << a.content.to_s }
          return [] if parts.empty?

          MentionExtractor.new(parts.join(" ")).bibliography_ids
        end
      end
    end
  end
end
