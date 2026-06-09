# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        autoload :LocalFileSystem,
                 "metanorma/plugin/glossarist/liquid/multiply_local_file_system"
        autoload :ManagedConceptDataDrop,
                 "metanorma/plugin/glossarist/liquid/drops/managed_concept_data_drop"
        autoload :ManagedConceptDrop,
                 "metanorma/plugin/glossarist/liquid/drops/managed_concept_drop"
        autoload :LocalizationCollectionDrop,
                 "metanorma/plugin/glossarist/liquid/drops/localization_collection_drop"
        autoload :PolyfillIndexedAccess,
                 "metanorma/plugin/glossarist/liquid/drop_bracket_access"
        autoload :WithGlossaristContext,
                 "metanorma/plugin/glossarist/liquid/custom_blocks/with_glossarist_context"
        autoload :CustomFilters,
                 "metanorma/plugin/glossarist/liquid/custom_filters"
      end
    end
  end
end
