# frozen_string_literal: true

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
          template = Liquid::Template.parse(file_content)
          template.registers[:file_system] = file_system
          template.render(strict_variables: false, error_mode: :warn)
        end
      end
    end
  end
end
