# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module CustomBlocks
          class WithGlossaristContext < ::Liquid::Block
            def initialize(tag_name, markup, tokens) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
              super

              @contexts = []
              @filters = {}

              contexts, filters = markup.strip.split(";", 2)

              if filters && !filters.empty?
                filters = filters.strip.gsub(/^['"]|['"]$/, "").split(";")
                filters.each do |filter|
                  property, value = filter.split("=")
                  @filters[property] = value
                end
              end

              contexts.split(",").each do |context|
                context_name, file_path = context.split("=").map(&:strip)

                @contexts << {
                  name: context_name,
                  file_path: file_path,
                }
              end
            end

            def load_collection(folder_path)
              @@collections ||= {}

              return @@collections[folder_path] if @@collections[folder_path]

              collection = ::Glossarist::ManagedConceptCollection.new
              collection.load_from_files(folder_path)
              @@collections[folder_path] = collection
            end

            def filter_collection(collection, filters)
              return collection unless filters

              concept_filters = filters.dup
              lang_filter = concept_filters.delete("lang")
              group_filter = concept_filters.delete("group")
              sort_filter = concept_filters.delete("sort_by")

              collection = apply_lang_filter(collection, lang_filter)
              collection = apply_group_filter(collection, group_filter)
              collection = apply_field_filter(collection, concept_filters)
              apply_sort_filter(collection, sort_filter)
            end

            def apply_field_filter(collection, field_filter) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
              return collection if field_filter.nil? || field_filter.empty?

              collection.select do |obj| # rubocop:disable Metrics/BlockLength
                fields = field_filter.keys.first.split(".")
                value = field_filter.values.first
                start_with = false

                # check if the last field is a start_with condition
                if fields.last.start_with?("start_with(") &&
                    fields.last.include?(")")
                  start_with = true
                  # Extract content between first '(' and last ')'
                  f = fields.last
                  value = f[(f.index("(") + 1)...f.rindex(")")]
                  fields = fields[0..-2]
                end

                fields.each do |field|
                  # contain index (i.e. field['abc'] or field[1])
                  if field.include?("[")
                    field, index = field[0..-2].split("[")

                    index = if index.include?("'") || index.include?("\"")
                              index.gsub(/['"]/, "")
                            else
                              index.to_i
                            end

                    obj = obj.send(field.to_sym)[index]
                  else
                    obj = obj.send(field.to_sym)
                  end
                end

                # check if the object matches the value
                if start_with
                  obj.start_with?(value)
                else
                  obj == value
                end
              end
            end

            def apply_lang_filter(collection, lang_filter)
              return collection unless lang_filter

              collection.select do |concept|
                concept.data.localizations.key?(lang_filter)
              end
            end

            def apply_group_filter(collection, group_filter)
              return collection unless group_filter

              collection.select do |concept|
                concept.data.groups&.include?(group_filter)
              end
            end

            def apply_sort_filter(collection, sort_filter)
              return collection unless sort_filter

              sort_filter = case sort_filter
                            when "term"
                              "default_designation"
                            else
                              sort_filter
                            end

              collection.sort_by do |concept|
                concept.send(sort_filter.to_sym).downcase
              end
            end

            def render(context)
              @contexts.each do |local_context|
                context_file = local_context[:file_path].strip
                collection = load_collection(context_file)

                filtered_collection = filter_collection(collection, @filters)

                context[local_context[:name]] = filtered_collection
                  .map(&:to_liquid)
              end

              super
            end
          end
        end
      end
    end
  end
end
