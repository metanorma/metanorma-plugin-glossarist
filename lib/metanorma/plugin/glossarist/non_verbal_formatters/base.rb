# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module NonVerbalFormatters
        # Shared rendering helpers for non-verbal entity formatters.
        #
        # Each formatter owns the kind-specific body (image block, table
        # block, stem block) and delegates anchor, caption, and a11y
        # framing to this base. Localized text is resolved by ISO 639 code
        # with graceful fallback to the first available value.
        class Base
          def initialize(entity, lang: "eng")
            @entity = entity
            @lang = lang
          end

          def to_asciidoc
            parts = [anchor_line, caption_line, body].compact.reject(&:empty?)
            "#{parts.join("\n")}\n"
          end

          protected

          attr_reader :entity, :lang

          # Subclasses implement this with the kind-specific AsciiDoc body
          # (e.g. image::, table, stem block).
          def body
            raise NotImplementedError
          end

          def anchor_line
            id = entity.id
            id ? "[[#{id}]]" : nil
          end

          def caption_line
            text = localized(entity.caption)
            text ? ".#{text}" : nil
          end

          def alt_text
            localized(entity.alt)
          end

          def description_text
            localized(entity.description)
          end

          # Picks the value for the requested language, falling back to
          # the first available value if missing. Returns nil for empty
          # or absent hashes.
          def localized(hash)
            return nil if hash.nil? || hash.empty?

            hash[lang] || hash.values.first
          end
        end
      end
    end
  end
end
