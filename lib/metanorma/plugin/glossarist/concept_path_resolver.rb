# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptPathResolver
        DELEGATED_TO_DATA = %w[localizations tags].freeze
        DATA_ALIASES = { "identifier" => :id }.freeze

        def resolve(concept, path)
          parts = parse_path(path)
          value = navigate(concept, parts)
          value.is_a?(String) ? value : value.to_s
        end

        private

        def parse_path(path)
          path.split(".").flat_map do |segment|
            if segment.include?("[")
              parse_indexed_segment(segment)
            else
              [segment]
            end
          end
        end

        def parse_indexed_segment(segment)
          field, index_part = segment.split("[", 2)
          index = index_part&.delete("]'\"")
          if index.match?(/\A\d+\z/)
            [field, index.to_i]
          else
            [field, index]
          end
        end

        def navigate(obj, parts)
          parts.reduce(obj) do |current, key|
            return nil if current.nil?

            access(current, key)
          end
        end

        def access(obj, key)
          case key
          when String then access_string_key(obj, key)
          when Integer then access_index(obj, key)
          end
        end

        def access_string_key(obj, key)
          case obj
          when ::Glossarist::ManagedConcept
            resolve_managed_concept(obj, key)
          when ::Glossarist::ManagedConceptData
            resolve_data_attribute(obj, key)
          when ::Glossarist::Collections::LocalizationCollection
            obj.find_by(:language_code, key)
          when Array
            nil
          when ::Lutaml::Model::Serializable
            resolve_attribute(obj, key)
          when Hash
            obj[key] || obj[key.to_s]
          end
        end

        def resolve_managed_concept(concept, key)
          return concept.data.public_send(key) if DELEGATED_TO_DATA.include?(key)

          resolve_attribute(concept, key) { concept.public_send(key.to_sym) }
        rescue NoMethodError
          nil
        end

        def resolve_data_attribute(data, key)
          aliased = DATA_ALIASES[key]
          return data.public_send(aliased) if aliased && data.class.attributes.key?(aliased)

          resolve_attribute(data, key)
        end

        def resolve_attribute(obj, key)
          sym = key.to_sym
          return obj.public_send(sym) if obj.class.attributes.key?(sym)

          yield if block_given?
        end

        def access_index(obj, index)
          obj[index]
        rescue NoMethodError
          nil
        end
      end
    end
  end
end
