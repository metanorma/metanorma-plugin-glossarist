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
      #
      # Collections are +Array<Figure|Table|Formula>+ as returned by
      # +GlossaryStore#figures/#tables/#formulas+. Lookups by id
      # (for concept→entity refs) use a lazily-built index that includes
      # Figure subfigures, preserving the recursive +Figure#find_by_id+
      # semantics of the previous Collection-based path.
      class NonVerbalRenderer
        FORMATTERS = {
          figures: NonVerbalFormatters::Figure,
          tables: NonVerbalFormatters::Table,
          formulas: NonVerbalFormatters::Formula,
        }.freeze

        # @param collections [Hash{Symbol => Array<NonVerbalEntity>, nil}]
        #   one entry per non-verbal kind, e.g.
        #   `{ figures: Array<Glossarist::Figure>, ... }`.
        #   Missing or nil entries are silently skipped.
        def initialize(collections:, lang: "eng")
          @collections = collections
          @lang = lang
          @indices = {}
        end

        # Render every entity in the named collection.
        #
        # @param kind [Symbol] key in FORMATTERS (e.g. +:figures+)
        # @return [String] AsciiDoc blocks joined by blank lines, or ""
        def render_kind(kind)
          entities = @collections[kind]
          return "" if entities.nil? || entities.empty?

          "#{entities.map { |e| format_one(kind, e) }.join("\n\n")}\n"
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
          entity = index_for(kind)[ref.entity_id]
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

        # Lazily builds and caches a {id => entity} index for the named
        # kind. Figures include their subfigures recursively; other kinds
        # are flat by id. Returns {} for missing/empty collections so
        # lookups naturally return nil.
        def index_for(kind)
          @indices[kind] ||= build_index(@collections[kind])
        end

        def build_index(entities)
          return {} if entities.nil? || entities.empty?

          entities.each_with_object({}) { |e, h| index_entity(h, e) }
        end

        def index_entity(index, entity)
          index[entity.id] = entity
          return unless entity.is_a?(::Glossarist::Figure)

          Array(entity.subfigures).each { |sub| index_entity(index, sub) }
        end
      end
    end
  end
end
