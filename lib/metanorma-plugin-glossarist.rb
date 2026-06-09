# frozen_string_literal: true

require "metanorma/plugin/glossarist/version"
require "metanorma-utils"
require "glossarist"

module Metanorma
  module Plugin
    module Glossarist
      autoload :BibliographyRenderer,
               "metanorma/plugin/glossarist/bibliography_renderer"
      autoload :ConceptFilter, "metanorma/plugin/glossarist/concept_filter"
      autoload :ConceptPathResolver,
               "metanorma/plugin/glossarist/concept_path_resolver"
      autoload :DatasetPreprocessor,
               "metanorma/plugin/glossarist/dataset_preprocessor"
      autoload :DatasetRegistry, "metanorma/plugin/glossarist/dataset_registry"
      autoload :Document, "metanorma/plugin/glossarist/document"
      autoload :Liquid, "metanorma/plugin/glossarist/liquid"
      autoload :LiquidRendering, "metanorma/plugin/glossarist/liquid_rendering"
      autoload :Sanitize, "metanorma/plugin/glossarist/sanitize"
      autoload :TemplateRenderer,
               "metanorma/plugin/glossarist/template_renderer"
    end
  end
end

Metanorma::Plugin::Glossarist::Liquid::PolyfillIndexedAccess.apply!
Metanorma::Plugin::Glossarist::Liquid::WithGlossaristContext.register!
Metanorma::Plugin::Glossarist::Liquid::CustomFilters::Filters.register!
