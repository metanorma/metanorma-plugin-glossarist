# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module LiquidRendering
        DEFAULT_PATTERNS = ["%s.liquid", "_%s.liquid"].freeze
        DOCUMENT_PATTERNS = ["%s.liquid", "_%s.liquid", "_%s.adoc"].freeze

        # Templates are parsed once per distinct source: rendering a large
        # vocabulary parses the same template thousands of times otherwise.
        # Liquid::Template is reusable across renders; errors accumulate on
        # the instance, so they are reset per render.
        def self.cached_template(content)
          @parsed_templates ||= {}
          @parsed_templates[content] ||= ::Liquid::Template.parse(content)
        end

        def self.render(content, include_paths:, patterns: DEFAULT_PATTERNS,
                        assigns: {}, registry: nil)
          template = cached_template(content)
          template.registers[:file_system] =
            Liquid::LocalFileSystem.new(include_paths, patterns)
          template.registers[:dataset_registry] = registry if registry
          template.errors.clear
          rendered = template.render(assigns)
          if template.errors.any?
            error = template.errors.first
            raise error.cause || error
          end

          rendered
        end
      end
    end
  end
end
