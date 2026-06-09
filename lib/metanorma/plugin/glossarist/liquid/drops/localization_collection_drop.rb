# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        class LocalizationCollectionDrop < ::Liquid::Drop
          include Enumerable

          def initialize(collection)
            super()
            @collection = collection
          end

          def liquid_method_missing(method)
            l10n = @collection.find_by(:language_code, method.to_s)
            l10n ? l10n.to_liquid : super
          end

          def [](key)
            liquid_method_missing(key.to_s)
          end

          def key?(key)
            !@collection.find_by(:language_code, key.to_s).nil?
          end

          def size
            @collection.size
          end

          def each(&block)
            @collection.each(&block)
          end

          def first
            @collection.first
          end

          def last
            @collection.last
          end
        end
      end
    end
  end
end
