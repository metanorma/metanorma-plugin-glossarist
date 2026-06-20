# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module NonVerbalFormatters
        # Renders a Glossarist::Figure as an AsciiDoc image block.
        #
        # Picks a single best image variant: vector (SVG) preferred for
        # resolution-independence, then any first image. Subfigures are
        # rendered recursively as separate image blocks so each carries
        # its own anchor and caption.
        class Figure < Base
          ROLE_PRIORITY = %w[vector raster print light dark].freeze

          protected

          def body
            image = best_image
            return subfigure_blocks if image.nil?

            line = "image::#{image.src}[#{image_attrs(image)}]"
            subfigure_blocks ? "#{line}\n\n#{subfigure_blocks}" : line
          end

          private

          def best_image
            images = Array(entity.images)
            return nil if images.empty?

            ROLE_PRIORITY.each do |role|
              found = images.find { |img| img.role == role }
              return found if found
            end
            images.first
          end

          def image_attrs(image)
            attrs = []
            attrs << alt_text if alt_text
            attrs << "width=#{image.width}" if image.width
            attrs << "height=#{image.height}" if image.height
            attrs.join(",")
          end

          def subfigure_blocks
            subs = Array(entity.subfigures)
            return nil if subs.empty?

            subs.map do |sub|
              self.class.new(sub, lang: lang).to_asciidoc
            end.join("\n").strip
          end
        end
      end
    end
  end
end
