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

        # Set this env var to share loaded datasets process-wide: one load
        # per dataset path per process instead of one per registry. Built
        # for metanorma's fragment-parallel compilation, which preloads the
        # document's datasets in the parent process and forks the fragment
        # workers from it: the workers then read the parent's loaded
        # models copy-on-write instead of re-parsing the dataset per
        # fragment. Also serves any single process that compiles several
        # documents over the same dataset (collection builds).
        #
        # The memo holds loaded models alive for the process lifetime and
        # shares them across every consumer: datasets that get mutated
        # after rendering, or unbounded sets of distinct large datasets,
        # must not enable it. Off by default.
        SHARED_STORE_ENV = "METANORMA_GLOSSARIST_SHARED_DATASETS"

        # One cached dataset: the loaded store, plus its concept array
        # once first requested (+GlossaryStore#concepts+ rebuilds the
        # array from the store's models on every call, which for a large
        # dataset is far from free).
        SharedDataset = Struct.new(:store, :concepts)

        class << self
          # Returns the process-wide SharedDataset entry for +path+,
          # calling the loader under the class mutex on first access, or
          # nil while the env gate is unset. The gate is read on every
          # access so tests and hosts can toggle it at any time.
          def shared_store_for(path)
            return nil unless shared_stores_enabled?

            shared_stores_mutex.synchronize do
              @shared_stores ||= {}
              @shared_stores[path] ||= SharedDataset.new(yield)
            end
          end

          # Forgets every shared entry. Spec support only: production use
          # keeps the memo for the process lifetime.
          def clear_shared_stores
            shared_stores_mutex.synchronize { @shared_stores = nil }
          end

          def shared_stores_mutex
            @shared_stores_mutex ||= Mutex.new
          end

          private

          def shared_stores_enabled?
            v = ENV.fetch(SHARED_STORE_ENV, nil)
            v && !v.empty? && v != "0"
          end
        end

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

        # The DatasetRegister of every registered context, loading each
        # lazily. Document citation resolution matches against all of
        # them, whatever the citation's source dataset.
        def registers
          @context_paths.filter_map { |name, _path| register_for(name) }
        end

        # Resolves citation parent documents against the registered
        # datasets' own URNs; memoized per document URN.
        def document_citations
          @document_citations ||= DocumentCitations.new(self)
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
          if (entry = shared_entry(path))
            entry.concepts ||= entry.store.concepts
          else
            store_for(path).concepts
          end
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
          if (entry = shared_entry(path))
            entry.store
          else
            @stores[path] ||= load_store_cached(path)
          end
        end

        # Returns the process-wide SharedDataset entry for +path+, loading
        # the store under the class mutex on first access, or nil when the
        # shared cache is disabled.
        def shared_entry(path)
          self.class.shared_store_for(path) { load_store_cached(path) }
        end

        # Content-addressed cache for the parsed concept models. Loading a
        # large dataset costs tens of seconds of per-file YAML parsing; the
        # parsed concept array Marshal-round-trips cleanly and deeply
        # equal, so a hit replaces the load outright. Opt-in: only active
        # when the consumer points GLOSSARIST_CACHE_DIR at a directory
        # they own — the library writes nothing unless asked.
        #
        # Datasets carrying non-verbal entity directories (figures,
        # tables, formulas) bypass the cache: their store state is richer
        # than the concept array this cache covers.
        def load_store_cached(path)
          cache_dir = ENV.fetch("GLOSSARIST_CACHE_DIR", nil)
          return load_store(path) if cache_dir.nil? || cache_dir.empty?

          file = concepts_cache_file(path, cache_dir)
          non_verbal = non_verbal_dataset?(path)
          cached = read_concepts_cache(file) unless non_verbal
          return CachedConceptsStore.new(cached) if cached

          store = load_store(path)
          write_concepts_cache(file, store.concepts) unless non_verbal
          store
        end

        def non_verbal_dataset?(path)
          NON_VERBAL_KINDS.any? do |kind|
            File.directory?(File.join(path, kind.to_s))
          end
        end

        def load_store(path)
          store = ::Glossarist::GlossaryStore.new
          store.load_directory(path)
          store
        end

        def read_concepts_cache(file)
          return nil unless File.exist?(file)

          begin
            # The cache file is written by this method, keyed by the
            # dataset's own content signature.
            Marshal.send(:load, File.binread(file))
          rescue TypeError, ArgumentError, EOFError
            File.delete(file) # stale or corrupt: fall through to a load
            nil
          end
        end

        def write_concepts_cache(file, concepts)
          tmp = "#{file}.#{Process.pid}.tmp"
          File.binwrite(tmp, Marshal.dump(concepts))
          File.rename(tmp, file)
        rescue TypeError
          File.delete(tmp) # concept graph not marshalable: cache disabled
        end

        def concepts_cache_file(path, cache_dir)
          require "digest"
          require "fileutils"
          signature = Dir.glob(File.join(path, "**", "*.{yaml,yml}"))
            .map { |f| [f.delete_prefix(path), File.size(f), File.mtime(f).to_i] }
            .hash
          key = Digest::SHA256.hexdigest("#{path}\0#{signature}")
          FileUtils.mkdir_p(cache_dir)
          File.join(cache_dir, "glossarist-concepts-#{key}.marshal")
        end

        # Minimal store stand-in answering exactly what DatasetRegistry
        # consumes from a cached dataset: the concept array. Non-verbal
        # kinds are covered by the directory guard above.
        CachedConceptsStore = Struct.new(:concepts_arr) do
          def concepts
            concepts_arr
          end

          %i[figures tables formulas].each do |kind|
            define_method(kind) { [] }
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
