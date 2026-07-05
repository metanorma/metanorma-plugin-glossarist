# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class Document
        attr_accessor :file_system, :registry

        def initialize
          @content = []
        end

        def add_raw(content)
          @content << content
        end

        def add_rendered(content, template: nil)
          include_paths = [file_system, TEMPLATES_DIR, template].compact
          @content << LiquidRendering.render(
            content,
            include_paths: include_paths,
            patterns: LiquidRendering::DOCUMENT_PATTERNS,
            registry: registry,
          )
        end

        def to_s
          @content.compact.join("\n")
        end
      end
    end
  end
end
