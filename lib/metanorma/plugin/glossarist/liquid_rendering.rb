# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      module LiquidRendering
        DEFAULT_PATTERNS = ["%s.liquid", "_%s.liquid"].freeze
        DOCUMENT_PATTERNS = ["%s.liquid", "_%s.liquid", "_%s.adoc"].freeze

        def self.render(content, include_paths:, patterns: DEFAULT_PATTERNS,
assigns: {})
          template = ::Liquid::Template.parse(content)
          template.registers[:file_system] =
            Liquid::LocalFileSystem.new(include_paths, patterns)
          rendered = template.render(assigns)
          raise template.errors.first.cause if template.errors.any?

          rendered
        end
      end
    end
  end
end
