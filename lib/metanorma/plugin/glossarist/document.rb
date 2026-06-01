# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      class Document
        attr_accessor :content, :file_system

        def initialize
          @content = []
        end

        def add_content(content, options = {})
          @content << if options[:render]
                        render_liquid(content, options)
                      else
                        content
                      end
        end

        def to_s
          @content.compact.join("\n")
        end

        private

        def render_liquid(file_content, options = {})
          include_paths = [file_system, options[:template]].compact
          template = ::Liquid::Template.parse(file_content)
          template.registers[:file_system] = ::Metanorma::Plugin::Glossarist::Liquid::LocalFileSystem.new(
            include_paths, ["%s.liquid", "_%s.liquid", "_%s.adoc"]
          )
          rendered = template.render

          return rendered unless template.errors.any?

          raise template.errors.first.cause
        end
      end
    end
  end
end
