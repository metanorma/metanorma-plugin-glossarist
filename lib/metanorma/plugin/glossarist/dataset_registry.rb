# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      # Resolves, caches, and exposes dataset models for a document.
      #
      # Single source of truth for everything the preprocessor needs from a
      # glossarist dataset: concepts, section hierarchy, bibliography, and
      # dataset-level non-verbal entities (figures, tables, formulas).
      # Each is exposed as the typed Glossarist model object so callers
      # never poke at raw YAML hashes.
      class DatasetRegistry
        BIBLIOGRAPHY_FILENAME = "bibliography.yaml"
        REGISTER_FILENAME = "register.yaml"

        # Non-verbal entity kinds exposed by GlossaryStore. Each kind
        # matches a method on +GlossaryStore+ (+#figures+, +#tables+,
        # +#formulas+) that returns an +Array<Figure|Table|Formula>+,
        # lazily loaded from +{dataset_path}/{kind}/*.yaml+.
        NON_VERBAL_KINDS = %i[figures tables formulas].freeze

        def initialize
          @stores = {}
          @registers = {}
          @bibliographies = {}
          @context_paths = {}
        end

        def register(document, contexts)
          contexts.split(";").map do |context|
            context_name, file_path = context.split(":", 2).map(&:strip)
            path = relative_file_path(document, file_path)
            @context_paths[context_name] = path
            "#{context_name}=#{path}"
          end
        end

        def resolve_dataset(document, dataset_name)
          return concepts_for(dataset_name) if @context_paths.key?(dataset_name)

          path = relative_file_path(document, dataset_name) if document
          return unless path

          concepts_at(path)
        end

        def find_concept(dataset_name, concept_name, document = nil)
          dataset = resolve_dataset(document, dataset_name)
          return unless dataset

          dataset.find { |concept| concept.default_designation == concept_name }
        end

        def context_path(key)
          @context_paths[key]
        end

        # Returns the DatasetRegister for a registered context, or nil.
        # The DatasetRegister is the single source of truth for section
        # hierarchy and concept→section membership (cascading ancestors).
        def register_for(context_name)
          path = @context_paths[context_name]
          return nil unless path

          register_at(path)
        end

        def register_sections(context_name)
          register_for(context_name)&.sections
        end

        # Returns the BibliographyData for a registered context, or nil.
        # Exposed as the typed model so callers iterate entries via
        # BibliographyEntry accessors (#id, #reference, #title, #link).
        def bibliography_for(context_name)
          path = @context_paths[context_name]
          return nil unless path

          bibliography_at(path)
        end

        # Returns concepts cached at an absolute path. Used by Liquid
        # blocks that receive a pre-resolved absolute path.
        def concepts_at(path)
          store_for(path).concepts
        end

        # Returns the Array of dataset-level non-verbal entities of the
        # given kind for a registered context (e.g. +Array<Glossarist::Figure>+),
        # or +nil+ if the context isn't registered. Empty Array means the
        # dataset has no +{kind}/+ subdirectory.
        #
        # +kind+ must be one of +NON_VERBAL_KINDS+. The kind symbol is the
        # message sent to +GlossaryStore+ — adding a new kind requires both
        # a GlossaryStore accessor and an entry here.
        def non_verbal_collection(context_name, kind)
          unless NON_VERBAL_KINDS.include?(kind)
            raise ArgumentError, "unknown non-verbal kind: #{kind.inspect}"
          end

          path = @context_paths[context_name]
          return nil unless path

          store_for(path).public_send(kind)
        end

        NON_VERBAL_KINDS.each do |kind|
          define_method("#{kind}_for") do |context_name|
            non_verbal_collection(context_name, kind)
          end
        end

        # Returns all available non-verbal collections for a context as a
        # hash keyed by kind symbol (e.g. +{ figures: Array<Figure> }+).
        # Kinds whose subdirectory doesn't exist are omitted. Convenient
        # for building a NonVerbalRenderer in one call.
        def non_verbal_collections(context_name)
          NON_VERBAL_KINDS.each_with_object({}) do |kind, memo|
            collection = non_verbal_collection(context_name, kind)
            memo[kind] = collection if collection && !collection.empty?
          end
        end

        private

        def concepts_for(context_name)
          path = @context_paths[context_name]
          path ? concepts_at(path) : nil
        end

        def store_for(path)
          @stores[path] ||= begin
            store = ::Glossarist::GlossaryStore.new
            store.load_directory(path)
            store
          end
        end

        def register_at(path)
          @registers[path] ||=
            ::Glossarist::DatasetRegister.from_directory(path)
        end

        def bibliography_at(path)
          @bibliographies[path] ||= begin
            file = File.join(path, BIBLIOGRAPHY_FILENAME)
            ::Glossarist::BibliographyData.from_file(file)
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
