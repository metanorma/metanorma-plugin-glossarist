# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module NonVerbalFormatters
        # Renders a Glossarist::Table as an AsciiDoc table block.
        #
        # Two payload shapes are supported:
        #   - +format: structured+ — +content+ has +headers+ and +rows+
        #     arrays, rendered as an AsciiDoc table.
        #   - +format: asciidoc+ (or any non-structured) — +content+ is a
        #     raw markup string emitted verbatim between caption and the
        #     next block.
        class Table < Base
          STRUCTURED = "structured"

          protected

          def body
            entity.format == STRUCTURED ? structured_table : raw_block
          end

          private

          def structured_table
            lines = ["|==="]
            append_headers(lines)
            Array(entity.content&.dig("rows")).each do |row|
              lines << "|#{Array(row).join(' |')}"
            end
            lines << "|==="
            lines.join("\n")
          end

          def append_headers(lines)
            headers = Array(entity.content&.dig("headers"))
            lines << "|#{headers.join(' |')}" unless headers.empty?
          end

          def raw_block
            content = entity.content
            (content&.dig("asciidoc") || content&.dig("text")).to_s
          end
        end
      end
    end
  end
end
