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
              context_name, file_path = context.split("=").map(&:strip)
              @contexts << { name: context_name, file_path: file_path }
            end
          end

          def render(context)
            @contexts.each do |local_context|
              collection = load_collection(local_context[:file_path].strip)
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

          def load_collection(folder_path)
            collection = ::Glossarist::ManagedConceptCollection.new
            collection.load_from_files(folder_path)
            collection
          end
        end
      end
    end
  end
end
