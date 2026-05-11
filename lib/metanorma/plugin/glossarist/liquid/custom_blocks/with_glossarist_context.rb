# frozen_string_literal: true

require "liquid"
require_relative "../../concept_filter"
require_relative "../../concept_serializer"

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module CollectionCache
          @cache = {}

          def self.fetch(folder_path)
            @cache[folder_path] ||= begin
              collection = ::Glossarist::ManagedConceptCollection.new
              collection.load_from_files(folder_path)
              collection
            end
          end
        end
      end
    end
  end
end

Liquid::Template.register_tag("with_glossarist_context",
                              Class.new(Liquid::Block) do
                                def initialize(tag_name, markup, tokens)
                                  super
                                  @contexts = []
                                  @raw_filters = {}

                                  contexts_part, filters_part = markup.strip.split(
                                    ";", 2
                                  )

                                  parse_filters(filters_part.strip) if filters_part && !filters_part.strip.empty?

                                  contexts_part.split(",").each do |context|
                                    context_name, file_path = context.split("=").map(&:strip)
                                    @contexts << { name: context_name,
                                                   file_path: file_path }
                                  end
                                end

                                def render(context)
                                  @contexts.each do |local_context|
                                    collection = load_collection(local_context[:file_path].strip)
                                    filtered = Metanorma::Plugin::Glossarist::ConceptFilter.new(@raw_filters).apply(collection)
                                    context[local_context[:name]] = filtered.map do |c|
                                      Metanorma::Plugin::Glossarist::ConceptSerializer.new(c).to_h
                                    end
                                  end

                                  super
                                end

                                private

                                def parse_filters(filters_str)
                                  stripped = filters_str.gsub(/\A['"]|['"]\z/,
                                                              "")
                                  stripped.split(";").each do |filter|
                                    property, value = filter.split("=", 2)
                                    if property
                                      @raw_filters[property.strip] =
                                        value&.strip
                                    end
                                  end
                                end

                                def load_collection(folder_path)
                                  Metanorma::Plugin::Glossarist::Liquid::CollectionCache.fetch(folder_path)
                                end
                              end)
