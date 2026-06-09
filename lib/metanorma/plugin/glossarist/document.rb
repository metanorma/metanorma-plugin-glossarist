# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class Document
        attr_accessor :file_system, :registry

        def initialize
          @content = []
        end

        def add_content(content, options = {})
          @content << if options[:render]
                        LiquidRendering.render(
                          content,
                          include_paths: [file_system,
                                          options[:template]].compact,
                          patterns: LiquidRendering::DOCUMENT_PATTERNS,
                          registry: registry,
                        )
                      else
                        content
                      end
        end

        def to_s
          @content.compact.join("\n")
        end
      end
    end
  end
end
