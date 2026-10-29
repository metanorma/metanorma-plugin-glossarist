# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Resolves a source citation's parent document into one bibliography
      # entry: anchor, display reference, and termsource locality.
      #
      # Extracted concepts cite their parent document with a per-item URN
      # ("urn:iso:std:iso:10303:-2:ed-1:en:tech:Activity_arm"). Rendering
      # that raw string as a citation produces an unresolvable docid that
      # metanorma escalates into a relaton fetch per occurrence. A document
      # is cited ONCE: the citation splits into document identity
      # (Citation#document_urn) and item path (Citation#item_path), the
      # document identity matches a registered dataset's own URN, and the
      # dataset's display reference (DatasetRegister#ref) becomes the
      # citeas — the dataset is the single source of truth for its
      # document's identity, with no network or docid parsing involved.
      class DocumentCitations
        ANCHOR_MANGLE = %r{[ /:]}

        # Feature probe: document citations need Citation#document_urn
        # (glossarist-ruby#253); on older models resolution is disabled
        # and citations keep the legacy rendering.
        SUPPORTED = ::Glossarist::Citation.method_defined?(:document_urn)

        # @param registry [DatasetRegistry] queried lazily, so registers
        #   registered after construction are still resolved
        def initialize(registry)
          @registry = registry
          @cache = {}
        end

        # @param citation [Glossarist::Citation, nil]
        # @return [Hash, nil] { anchor:, citeas:, locality: } for a URN
        #   citation whose document identity is known; nil otherwise
        def resolve(citation)
          return nil unless SUPPORTED
          return nil unless citation.is_a?(::Glossarist::Citation)

          urn = citation.document_urn
          return nil unless urn

          @cache[urn] ||= build(citation, urn)
        end

        private

        def build(citation, urn)
          register = matching_register(urn)
          {
            anchor: urn.gsub(ANCHOR_MANGLE, "_"),
            citeas: register&.ref || urn,
            locality: locality_markup(citation.item_path),
          }
        end

        def matching_register(urn)
          @registry.registers.find do |register|
            register_urn = register.urn
            register_urn && document_identity(register_urn) == urn
          end
        end

        def document_identity(urn)
          segments = urn.split(":")
          idx = segments.index do |segment|
            ::Glossarist::Citation::URN_ELEMENT_SEGMENTS.include?(segment)
          end
          idx ? segments[0...idx].join(":") : urn
        end

        # "tech:Activity_arm:tech:Activity_arm" — the trailing repetition
        # is extraction redundancy; the first element pair carries the
        # item. Rendered as a metanorma custom locality so termsource
        # gains <locality type="tech"><referenceFrom>Activity_arm>.
        def locality_markup(item_path)
          return nil unless item_path

          kind, name = item_path.split(":")
          return nil unless kind && name && !name.empty?

          "locality:#{kind}=#{name}"
        end
      end
    end
  end
end
