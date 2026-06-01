# frozen_string_literal: true

require "asciidoctor"
require "asciidoctor/reader"
require "glossarist"

module Metanorma
  module Plugin
    module Glossarist
      class DatasetPreprocessor < Asciidoctor::Extensions::Preprocessor
        DATASET_ATTR_REGEX = /^:glossarist-dataset:\s*(.*?)$/m
        IMPORT_REGEX = /^glossarist::import\[(.*?)\]$/m
        RENDER_REGEX = /^glossarist::render\[(.*?)\]$/m
        BLOCK_REGEX = /^\[glossarist,(.+?),(.+?)\]$/m
        BIBLIOGRAPHY_REGEX = /^glossarist::render_bibliography\[(.*?)\]$/m
        BIBLIOGRAPHY_ENTRY_REGEX = /^glossarist::render_bibliography_entry\[(.*?)\]$/m

        BIB_ANCHOR_REGEX = /^\*\s*\[\[\[([^,]+)/

        def initialize(config = {})
          super
          @config = config
          @datasets = {}
          @rendered_concepts = []
          @title_depth = 2
          @existing_bib_anchors = []
          @bibliography_data = {}
          @seen_glossarist = false
          @context_names = []
        end

        def process(document, reader)
          input_lines = reader.lines.to_enum
          @config[:file_system] = relative_file_path(document, "")
          processed_doc = prepare_document(document, input_lines)
          log(document, processed_doc.to_s) if @seen_glossarist
          Asciidoctor::PreprocessorReader.new(document,
                                              processed_doc.to_s.split("\n"))
        end

        protected

        def log(doc, text)
          File.open("#{doc.attr('docfile')}.glossarist.log.txt",
                    "w:UTF-8") do |f|
            f.write(text)
          end
        end

        private

        def prepare_document(document, input_lines, end_mark = nil,
                             skip_dataset: false)
          liquid_doc = Document.new
          liquid_doc.file_system = @config[:file_system]

          loop do
            current_line = input_lines.next
            break if end_mark && current_line == end_mark

            unless skip_dataset && current_line.start_with?(":glossarist-dataset:")
              process_line(document, input_lines, current_line, liquid_doc)
            end
          end

          liquid_doc
        end

        def process_line(document, input_lines, current_line, liquid_doc)
          if (match = current_line.match(DATASET_ATTR_REGEX))
            process_dataset_tag(document, input_lines, liquid_doc, match)
          elsif (match = current_line.match(RENDER_REGEX))
            process_render_tag(liquid_doc, match)
          elsif (match = current_line.match(IMPORT_REGEX))
            process_import_tag(liquid_doc, match)
          elsif (match = current_line.match(BIBLIOGRAPHY_REGEX))
            process_bibliography(document, liquid_doc, match)
          elsif (match = current_line.match(BIBLIOGRAPHY_ENTRY_REGEX))
            process_bibliography_entry(document, liquid_doc, match)
          elsif (match = current_line.match(BLOCK_REGEX))
            process_glossarist_block(document, liquid_doc, input_lines, match)
          else
            if /^==+ \S/.match?(current_line)
              @title_depth = current_line.sub(/ .*$/,
                                              "").size
            end
            if (match = current_line.match(BIB_ANCHOR_REGEX))
              @existing_bib_anchors << match[1]
            end
            liquid_doc.add_content(current_line)
          end
        end

        def process_dataset_tag(document, input_lines, liquid_doc, match)
          @seen_glossarist = true
          @context_names << prepare_dataset_contexts(document, match[1])
          @context_names.flatten!
          liquid_doc.add_content(prepare_document(document, input_lines).to_s,
                                 render: false)
        end

        def process_glossarist_block(document, liquid_doc, input_lines, match)
          @seen_glossarist = true
          end_mark = input_lines.next

          params, template = prepare_glossarist_block_params(document, match)
          section = <<~SECTION.strip
            {% with_glossarist_context #{params} %}
            #{prepare_document(document, input_lines, end_mark, skip_dataset: true)}
            {% endwith_glossarist_context %}
          SECTION

          options = { render: true }
          options[:template] = template if template
          liquid_doc.add_content(section, options)
        end

        def prepare_glossarist_block_params(document, match)
          path = get_context_path(document, match[1])
          matched_arr = match[2].split(",").map(&:strip)
          context_name = matched_arr.last

          params = ["#{context_name}=#{path}"]
          template = nil

          matched_arr[0..-2].each do |item|
            if item.start_with?("filter=")
              filters = item.delete_prefix("filter=").strip
              params << filters
            elsif item.start_with?("template=")
              template = relative_file_path(document,
                                            item.delete_prefix("template=").strip)
            end
          end

          [params.join(";"), template]
        end

        def get_context_path(document, key)
          if @context_names && !@context_names.empty?
            context_names = @context_names.map(&:strip)
            found = context_names.find do |context|
              context_name, = context.split("=")
              context_name == key
            end
            return found.split("=").last.strip if found
          end

          relative_file_path(document, key)
        end

        def process_render_tag(liquid_doc, match)
          @seen_glossarist = true
          matches = match[1].split(",").map(&:strip)
          context_name = matches[0]
          concept_name = matches[1]
          options = parse_options(matches[2..])

          concept = find_concept(context_name, concept_name)
          return unless concept

          @rendered_concepts << concept
          renderer = TemplateRenderer.new(file_system: @config[:file_system])
          rendered = renderer.render_concept(concept,
                                            depth: @title_depth,
                                            anchor_prefix: options["anchor-prefix"])
          liquid_doc.add_content("\n#{rendered}")
        end

        RENDER_OPTIONS = %w[anchor-prefix].freeze

        def process_import_tag(liquid_doc, match)
          @seen_glossarist = true
          matches = match[1].split(",").map(&:strip)
          context_name = matches[0]
          options = parse_options(matches[1..])
          dataset = @datasets[context_name.strip]
          return unless dataset

          filter_options = options.reject { |k, _| RENDER_OPTIONS.include?(k) }
          concepts = ConceptFilter.new(filter_options).apply(dataset)
          concepts = concepts.select { |c| c.default_designation }
          @rendered_concepts.concat(concepts)
          renderer = TemplateRenderer.new(file_system: @config[:file_system])
          rendered = renderer.render_concepts(concepts,
                                              depth: @title_depth,
                                              anchor_prefix: options["anchor-prefix"])
          liquid_doc.add_content("\n#{rendered}")
        end

        def process_bibliography(document, liquid_doc, match)
          @seen_glossarist = true
          dataset_name = match[1].strip
          concepts = @rendered_concepts.empty? ? resolve_dataset(document, dataset_name) : @rendered_concepts
          return unless concepts && !concepts.empty?

          renderer = BibliographyRenderer.new(
            existing_anchors: @existing_bib_anchors,
            bibliography_data: @bibliography_data,
          )
          liquid_doc.add_content(renderer.render_all(concepts))
        end

        def process_bibliography_entry(document, liquid_doc, match)
          @seen_glossarist = true
          dataset_name, concept_name = match[1].split(",").map(&:strip)
          concept = find_concept(dataset_name, concept_name, document)
          return unless concept

          renderer = BibliographyRenderer.new(
            existing_anchors: @existing_bib_anchors,
            bibliography_data: @bibliography_data,
          )
          entry = renderer.render_entry(concept)
          liquid_doc.add_content(entry) if entry
        end

        def prepare_dataset_contexts(document, contexts)
          contexts.split(";").map do |context|
            context_name, file_path = context.split(":").map(&:strip)
            path = relative_file_path(document, file_path)
            dataset = load_dataset(path)
            @datasets[context_name] = dataset.to_a
            load_bibliography_data(path)
            "#{context_name}=#{path}"
          end
        end

        def load_bibliography_data(dataset_path)
          bib_path = File.join(dataset_path, "bibliography.yaml")
          return unless File.exist?(bib_path)

          entries = YAML.safe_load(File.read(bib_path), permitted_classes: [Symbol, Date])
          return unless entries.is_a?(Array)

          @bibliography_data = entries.each_with_object({}) do |entry, hash|
            hash[entry["id"]] = entry if entry["id"]
          end
        end

        def load_dataset(path)
          collection = ::Glossarist::ManagedConceptCollection.new
          collection.load_from_files(path)
          collection
        end

        def find_concept(dataset_name, concept_name, document = nil)
          dataset = resolve_dataset(document, dataset_name)
          return unless dataset

          dataset.find do |concept|
            concept.default_designation == concept_name
          end
        end

        def resolve_dataset(document, dataset_name)
          dataset = @datasets[dataset_name]
          return dataset if dataset

          return unless document

          path = relative_file_path(document, dataset_name)
          collection = load_dataset(path)
          @datasets[dataset_name] = collection.to_a
        end

        def relative_file_path(document, file_path)
          docfile_directory = File.dirname(
            document.attributes["docfile"] || ".",
          )
          document.path_resolver.system_path(file_path, docfile_directory)
        end

        def parse_options(options_arr)
          return {} if !options_arr || options_arr.empty?

          options_arr.each_with_object({}) do |option, hash|
            key, value = option.split("=", 2)
            hash[key] = value if key && value
          end
        end
      end
    end
  end
end
