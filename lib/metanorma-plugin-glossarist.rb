# frozen_string_literal: true

require "metanorma/plugin/glossarist/version"
require "metanorma-utils"
require "glossarist"

module Metanorma
  module Plugin
    module Glossarist
      TEMPLATES_DIR = File.join(File.dirname(__FILE__), "metanorma",
                                "plugin", "glossarist", "liquid_templates").freeze

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
      autoload :NonVerbalFormatters,
               "metanorma/plugin/glossarist/non_verbal_formatters"
      autoload :NonVerbalRenderer,
               "metanorma/plugin/glossarist/non_verbal_renderer"
      autoload :Sanitize, "metanorma/plugin/glossarist/sanitize"
      autoload :SectionCascade, "metanorma/plugin/glossarist/section_cascade"
      autoload :SectionFilter, "metanorma/plugin/glossarist/section_filter"
      autoload :SectionRenderer, "metanorma/plugin/glossarist/section_renderer"
      autoload :TemplateRenderer,
               "metanorma/plugin/glossarist/template_renderer"
    end
  end
end

Metanorma::Plugin::Glossarist::Liquid::PolyfillIndexedAccess.apply!
Metanorma::Plugin::Glossarist::Liquid::WithGlossaristContext.register!
Metanorma::Plugin::Glossarist::Liquid::CustomFilters::Filters.register!
