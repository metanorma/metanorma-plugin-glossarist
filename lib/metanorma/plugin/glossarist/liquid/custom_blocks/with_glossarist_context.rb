# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        class WithGlossaristContext < ::Liquid::Block
          def self.register!
            ::Liquid::Environment.default.register_tag(
              "with_glossarist_context", self
            )
          end

          def initialize(tag_name, markup, tokens)
            super
            @contexts = []
            @raw_filters = {}

            contexts_part, filters_part = markup.strip.split(";", 2)

            parse_filters(filters_part.strip) if filters_part && !filters_part.strip.empty?

            contexts_part.split(",").each do |context|
              context_name, file_path = context.split("=", 2).map(&:strip)
              @contexts << { name: context_name, file_path: file_path }
            end
          end

          def render(context)
            registry = context.registers[:dataset_registry]

            @contexts.each do |local_context|
              path = local_context[:file_path].strip
              collection = concepts_for(registry, path)
              filtered = ConceptFilter.new(@raw_filters).apply(collection)
              context[local_context[:name]] = filtered.map do |c|
                ManagedConceptDrop.new(c)
              end
            end

            super
          end

          private

          def parse_filters(filters_str)
            stripped = filters_str.gsub(/\A['"]|['"]\z/, "")
            stripped.split(";").each do |filter|
              property, value = filter.split("=", 2)
              @raw_filters[property.strip] = value&.strip if property
            end
          end

          def concepts_for(registry, path)
            return registry.concepts_at(path) if registry

            fallback_store(path).concepts
          end

          def fallback_store(path)
            ::Glossarist::GlossaryStore.new.load_directory(path)
          end
        end
      end
    end
  end
end
