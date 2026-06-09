# frozen_string_literal: true

require "glossarist"

module Metanorma
  module Plugin
    module Glossarist
      class DatasetRegistry
        def initialize
          @datasets = {}
          @path_cache = {}
          @bibliography_data = {}
          @context_names = []
        end

        def register(document, contexts)
          paths = contexts.split(";").map do |context|
            context_name, file_path = context.split(":").map(&:strip)
            path = relative_file_path(document, file_path)
            @datasets[context_name] = load_dataset(path).to_a
            "#{context_name}=#{path}"
          end
          @context_names.concat(paths)
        end

        def load_cached(path)
          @path_cache[path] ||= load_dataset(path)
        end

        def resolve_dataset(document, dataset_name)
          dataset = @datasets[dataset_name]
          return dataset if dataset

          return unless document

          path = relative_file_path(document, dataset_name)
          @datasets[dataset_name] = load_dataset(path).to_a
        end

        def find_concept(dataset_name, concept_name, document = nil)
          dataset = resolve_dataset(document, dataset_name)
          return unless dataset

          dataset.find do |concept|
            concept.default_designation == concept_name
          end
        end

        def context_path(key)
          return nil if @context_names.empty?

          found = @context_names.find do |context|
            context_name, = context.split("=")
            context_name.strip == key
          end
          found&.split("=")&.last&.strip
        end

        def bibliography_data
          @bibliography_data
        end

        private

        def load_dataset(path)
          @path_cache[path] ||= begin
            collection = ::Glossarist::ManagedConceptCollection.new
            collection.load_from_files(path)
            load_bibliography_data(path)
            collection
          end
        end

        def load_bibliography_data(dataset_path)
          bib_path = File.join(dataset_path, "bibliography.yaml")
          return unless File.exist?(bib_path)

          entries = YAML.safe_load_file(bib_path,
                                        permitted_classes: [Symbol, Date])
          return unless entries.is_a?(Array)

          @bibliography_data = entries.each_with_object({}) do |entry, hash|
            hash[entry["id"]] = entry if entry["id"]
          end
        end

        def relative_file_path(document, file_path)
          return file_path if File.absolute_path?(file_path)

          docfile_directory = File.dirname(
            document.attributes["docfile"] || ".",
          )
          document.path_resolver.system_path(file_path, docfile_directory)
        end
      end
    end
  end
end
