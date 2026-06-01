# frozen_string_literal: true

require "metanorma/plugin/glossarist/version"
require "metanorma-utils"
require "glossarist"

module Metanorma
  module Plugin
    module Glossarist
      autoload :BibliographyRenderer, "metanorma/plugin/glossarist/bibliography_renderer"
      autoload :ConceptFilter, "metanorma/plugin/glossarist/concept_filter"
      autoload :ConceptPathResolver, "metanorma/plugin/glossarist/concept_path_resolver"
      autoload :DatasetPreprocessor, "metanorma/plugin/glossarist/dataset_preprocessor"
      autoload :Document, "metanorma/plugin/glossarist/document"
      autoload :Sanitize, "metanorma/plugin/glossarist/sanitize"
      autoload :TemplateRenderer, "metanorma/plugin/glossarist/template_renderer"
    end
  end
end

require "metanorma/plugin/glossarist/liquid/multiply_local_file_system"
require "metanorma/plugin/glossarist/liquid/drops/localization_collection_drop"
require "metanorma/plugin/glossarist/liquid/drops/managed_concept_drop"
require "metanorma/plugin/glossarist/liquid/drop_bracket_access"
require "metanorma/plugin/glossarist/liquid/custom_blocks/with_glossarist_context"
require "metanorma/plugin/glossarist/liquid/custom_filters/filters"
