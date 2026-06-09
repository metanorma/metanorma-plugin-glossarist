# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module CustomFilters
          module Filters
            def self.register!
              ::Liquid::Environment.default.register_filter(self)
            end

            def values(list)
              list.values
            end

            def sanitize_references(str)
              Sanitize.references(str)
            end

            def format_ref(label)
              return "" if label.nil? || label.strip.empty?

              label.gsub(%r{[ /:]}, "_")
            end
          end
        end
      end
    end
  end
end
