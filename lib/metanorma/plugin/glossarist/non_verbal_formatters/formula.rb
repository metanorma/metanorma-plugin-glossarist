# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module NonVerbalFormatters
        # Renders a Glossarist::Formula as an AsciiDoc stem block.
        #
        # The expression hash is keyed by language (matching caption/alt);
        # the +notation+ field carries the markup language (latex, mathml,
        # asciimath) but the body is format-agnostic — Metanorma's stem
        # block accepts any notation supported by the renderer.
        class Formula < Base
          protected

          def body
            expr = localized(entity.expression)
            return "" if expr.nil? || expr.empty?

            <<~STEM
              [stem]
              ++++
              #{expr}
              ++++
            STEM
          end
        end
      end
    end
  end
end
