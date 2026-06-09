# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module CustomFilters
          autoload :Filters,
                   "metanorma/plugin/glossarist/liquid/custom_filters/filters"
        end
      end
    end
  end
end
