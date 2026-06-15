# frozen_string_literal: true

# Includes Lutaml::Model::Liquid::IndexedAccess into Glossarist collection
# classes so that their auto-generated Liquid drops support bracket access
# (e.g., +localizations['eng']+, +definition[0]+).
#
# Glossarist collections support +self[key]+ but do not yet include
# IndexedAccess in their published gem. Once they do, this file can be
# removed entirely.
#
# @see Lutaml::Model::Liquid::IndexedAccess (lutaml-model >= 0.8.15)
# @see https://github.com/lutaml/lutaml-model/pull/705
module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module PolyfillIndexedAccess
          COLLECTION_CLASSES = %w[
            Glossarist::Collections::LocalizationCollection
            Glossarist::Collections::DetailedDefinitionCollection
            Glossarist::Collections::ConceptSourceCollection
          ].freeze

          def self.apply!
            COLLECTION_CLASSES.each do |class_name|
              klass = class_name.split("::").reduce(Object) do |mod, name|
                mod.const_get(name)
              end
              klass.include(::Lutaml::Model::Liquid::IndexedAccess) unless klass.include?(::Lutaml::Model::Liquid::IndexedAccess)
            end
          end
        end
      end
    end
  end
end
