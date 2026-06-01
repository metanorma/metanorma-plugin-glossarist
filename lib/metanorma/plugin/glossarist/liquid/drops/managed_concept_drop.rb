# frozen_string_literal: true

require "liquid"

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
            @data_drop ||= ManagedConceptDataDrop.new(@concept.data)
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

        # Wraps ManagedConceptData to provide localizations as a
        # {LocalizationCollectionDrop} that supports bracket access.
        # Other attributes delegate to the auto-generated Lutaml::Model drop.
        class ManagedConceptDataDrop < ::Liquid::Drop
          def initialize(concept_data)
            super()
            @concept_data = concept_data
            @auto_drop = concept_data.to_liquid
          end

          def localizations
            @localizations_drop ||= LocalizationCollectionDrop.new(@concept_data.localizations)
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
