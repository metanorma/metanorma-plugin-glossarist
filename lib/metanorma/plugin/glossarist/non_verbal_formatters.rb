# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Namespace for per-kind AsciiDoc formatters for dataset-level
      # non-verbal entities. Adding a new kind = adding a new formatter
      # class and registering it in NonVerbalRenderer::FORMATTERS.
      module NonVerbalFormatters
        autoload :Base, "metanorma/plugin/glossarist/non_verbal_formatters/base"
        autoload :Figure,
                 "metanorma/plugin/glossarist/non_verbal_formatters/figure"
        autoload :Table,
                 "metanorma/plugin/glossarist/non_verbal_formatters/table"
        autoload :Formula,
                 "metanorma/plugin/glossarist/non_verbal_formatters/formula"
      end
    end
  end
end
