# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Renders dataset-level non-verbal entities (Figure, Table, Formula)
      # as AsciiDoc blocks. MECE sibling to BibliographyRenderer: where
      # BibliographyRenderer owns citation provenance, NonVerbalRenderer
      # owns the rendering of authored figures/tables/formulas.
      #
      # Per-kind formatting is delegated to a formatter class registered
      # in +FORMATTERS+. Adding a new kind = adding one formatter class
      # and one entry here; the dispatcher itself never changes shape.
      class NonVerbalRenderer
        FORMATTERS = {
          figures: NonVerbalFormatters::Figure,
          tables: NonVerbalFormatters::Table,
          formulas: NonVerbalFormatters::Formula,
        }.freeze

        # @param collections [Hash{Symbol => NonVerbalCollection, nil}]
        #   one entry per non-verbal kind, e.g.
        #   `{ figures: FigureCollection, tables: ..., formulas: ... }`.
        #   Missing or nil entries are silently skipped.
        def initialize(collections:, lang: "eng")
          @collections = collections
          @lang = lang
        end

        # Render every entity in the named collection.
        #
        # @param kind [Symbol] key in FORMATTERS (e.g. +:figures+)
        # @return [String] AsciiDoc blocks joined by blank lines, or ""
        def render_kind(kind)
          collection = @collections[kind]
          return "" if collection.nil? || collection.entries.empty?

          entries = collection.entries
          "#{entries.map { |e| format_one(kind, e) }.join("\n\n")}\n"
        end

        # Render the non-verbal entities referenced by a concept's
        # figures/tables/formulas ref collections, in deterministic order
        # (figures, tables, formulas). Unknown refs are skipped silently —
        # they will surface as missing anchors during Metanorma rendering.
        #
        # @param concept [Glossarist::ManagedConcept]
        # @return [String]
        def render_concept_refs(concept)
          FORMATTERS.keys.filter_map do |kind|
            refs = concept_refs(concept, kind)
            next if refs.empty?

            blocks = refs.filter_map { |ref| render_ref(kind, ref) }
            next if blocks.empty?

            "#{blocks.join("\n\n")}\n"
          end.join("\n")
        end

        private

        def render_ref(kind, ref)
          collection = @collections[kind]
          return nil unless collection

          entity = collection.by_id(ref.entity_id)
          return nil unless entity

          format_one(kind, entity)
        end

        def format_one(kind, entity)
          FORMATTERS.fetch(kind).new(entity, lang: @lang).to_asciidoc
        end

        def concept_refs(concept, kind)
          refs = concept.data&.public_send(kind)
          Array(refs)
        end
      end
    end
  end
end
