# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class Document
        attr_accessor :content, :bibliographies

        def initialize
          @content = []
          @bibliographies = []
        end

        def add_content(content)
          @content << content
        end

        def to_s
          @content.compact.join("\n")
        end

        def render_liquid(file_system)
          template = Liquid::Template.parse(to_s)
          template.registers[:file_system] = file_system
          template.render(strict_variables: false, error_mode: :warn)
        end
      end
    end
  end
end
