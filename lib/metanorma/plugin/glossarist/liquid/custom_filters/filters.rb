# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module CustomFilters
          module Filters
            def values(list)
              list.values
            end

            def sanitize_references(str)
              Sanitize.references(str)
            end
          end
        end
      end
    end
  end
end

Liquid::Template.register_filter(Metanorma::Plugin::Glossarist::Liquid::CustomFilters::Filters)
