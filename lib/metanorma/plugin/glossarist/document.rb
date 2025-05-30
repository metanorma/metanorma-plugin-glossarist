# frozen_string_literal: true

require_relative "liquid/custom_blocks/with_glossarist_context"
require_relative "liquid/custom_filters/filters"

module Metanorma
  module Plugin
    module Glossarist
      class Document
        attr_accessor :content, :bibliographies, :file_system

        def initialize
          @content = []
          @bibliographies = []
        end

        def add_content(content, options = {})
          @content << if options[:render]
                        render_liquid(content)
                      else
                        content
                      end
        end

        def to_s
          @content.compact.join("\n")
        end

        def render_liquid(file_content)
          template = ::Liquid::Template
            .parse(file_content, environment: create_liquid_environment)

          template.registers[:file_system] = file_system
          rendered_template = template.render(strict_variables: false,
                                              error_mode: :warn)

          return rendered_template unless template.errors.any?

          raise template.errors.first.cause
        end

        def create_liquid_environment
          ::Liquid::Environment.new.tap do |liquid_env|
            liquid_env.register_tag(
              "with_glossarist_context",
              ::Metanorma::Plugin::Glossarist::Liquid::CustomBlocks::
              WithGlossaristContext,
            )
            liquid_env.register_filter(
              ::Metanorma::Plugin::Glossarist::Liquid::CustomFilters::Filters,
            )
          end
        end
      end
    end
  end
end
