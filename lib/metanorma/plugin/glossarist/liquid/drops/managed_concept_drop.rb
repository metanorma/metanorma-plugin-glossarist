# frozen_string_literal: true


module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        class ManagedConceptDrop < ::Liquid::Drop
          def initialize(concept)
            super()
            @concept = concept
          end

          def data
            @data ||= ManagedConceptDataDrop.new(@concept.data)
          end

          def schema_version
            @concept.schema_version
          end

          def uuid
            @concept.uuid
          end

          def identifier
            @concept.identifier
          end

          def default_designation
            @concept.default_designation
          end

          def tags
            @concept.data.tags
          end

          def liquid_method_missing(method)
            l10n = @concept.localization(method.to_s)
            l10n ? l10n.to_liquid : super
          end
        end
      end
    end
  end
end
