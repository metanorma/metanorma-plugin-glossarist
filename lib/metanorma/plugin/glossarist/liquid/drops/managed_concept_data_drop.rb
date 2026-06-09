# frozen_string_literal: true


module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        class ManagedConceptDataDrop < ::Liquid::Drop
          def initialize(concept_data)
            super()
            @concept_data = concept_data
            @auto_drop = concept_data.to_liquid
          end

          def localizations
            @localizations ||= LocalizationCollectionDrop.new(@concept_data.localizations)
          end

          def identifier
            @concept_data.id
          end

          def liquid_method_missing(method)
            @auto_drop.invoke_drop(method)
          end
        end
      end
    end
  end
end
