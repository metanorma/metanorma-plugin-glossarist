# frozen_string_literal: true

require "asciidoctor"

require "liquid"
require "asciidoctor/reader"
require "glossarist"
require "metanorma/plugin/glossarist/document"
require "liquid/custom_blocks/with_glossarist_context"

require "liquid/drops/concepts_drop"
require "liquid/custom_filters/filters"

Liquid::Template
  .register_tag("with_glossarist_context",
                Liquid::CustomBlocks::WithGlossaristContext)
Liquid::Template.register_filter(Liquid::CustomFilters::Filters)

module Metanorma
  module Plugin
    module Glossarist
      class DatasetPreprocessor < Asciidoctor::Extensions::Preprocessor
        GLOSSARIST_DATASET_REGEX = /^:glossarist-dataset:\s*(.*?)$/m.freeze
        GLOSSARIST_IMPORT_REGEX = /^glossarist::import\[(.*?)\]$/m.freeze
        GLOSSARIST_RENDER_REGEX = /^glossarist::render\[(.*?)\]$/m.freeze

        GLOSSARIST_BLOCK_REGEX = /^\[glossarist,(.+?),(.+?)\]/
        GLOSSARIST_FILTER_BLOCK_REGEX = /^\[glossarist,(.+?),(filter=.+?),(.+?)\]/

        GLOSSARIST_BIBLIOGRAPHY_REGEX = /^glossarist::render_bibliography\[(.*?)\]$/m.freeze
        GLOSSARIST_BIBLIOGRAPHY_ENTRY_REGEX = /^glossarist::render_bibliography_entry\[(.*?)\]$/m.freeze

        # Search document for the following blocks
        #   - :glossarist-dataset: dataset1:./dataset1;dataset2:./dataset2
        #     This will load `glossarist` concepts from `./dataset1` path into
        #     `dataset1` and concepts from `./dataset2` path into `dataset2`,
        #     These can then be used anywhere in the document like
        #     {{dataset1.concept_name.en.definition.content}}
        #
        #   - glossarist:render[dataset1, concept_name]
        #     this will render the `concept_name` using the below format
        #
        #     ==== concept term
        #     alt:[if additional terms]
        #
        #     definition text
        #
        #     NOTE: if there is a note.
        #
        #     [example]
        #     If there is an example.
        #
        #     [.source]
        #     <<If there is some source>>
        #
        #   - glossarist:import[dataset1]
        #     this will render all concepts in the `dataset1` using the above
        #     format
        def initialize(config = {})
          super
          @config = config
          @datasets = {}
          @title_depth = { value: 2 }
          @rendered_bibliographies = {}
          @seen_glossarist = []
        end

        def process(document, reader)
          input_lines = reader.lines.to_enum

          file_system = ::Liquid::LocalFileSystem.new(
            relative_file_path(document, ""),
          )

          @config[:file_system] = file_system

          processed_doc = prepare_document(document, input_lines)
          log(document, processed_doc.to_s) unless @seen_glossarist.empty?
          Asciidoctor::PreprocessorReader.new(document,
                                              processed_doc.to_s.split("\n"))
        end

        protected

        def log(doc, text)
          File.open("#{doc.attr('docfile')}.glossarist.log.txt", "w:UTF-8") do |f|
            f.write(text)
          end
        end

        private

        def prepare_document(document, input_lines, end_mark = nil)
          liquid_doc = Document.new
          liquid_doc.file_system = @config[:file_system]

          loop do
            current_line = input_lines.next
            break if end_mark && current_line == end_mark

            process_line(document, input_lines, current_line, liquid_doc)
          end

          liquid_doc
        end

        def process_line(document, input_lines, current_line, liquid_doc)
          if match = current_line.match(GLOSSARIST_DATASET_REGEX)
            process_dataset_tag(document, input_lines, liquid_doc, match)
          elsif match = current_line.match(GLOSSARIST_RENDER_REGEX)
            process_render_tag(liquid_doc, match)
          elsif match = current_line.match(GLOSSARIST_IMPORT_REGEX)
            process_import_tag(liquid_doc, match)
          elsif match = current_line.match(GLOSSARIST_BIBLIOGRAPHY_REGEX)
            process_bibliography(liquid_doc, match)
          elsif match = current_line.match(GLOSSARIST_BIBLIOGRAPHY_ENTRY_REGEX)
            process_bibliography_entry(liquid_doc, match)
          elsif match = current_line.match(GLOSSARIST_FILTER_BLOCK_REGEX)
            process_glossarist_block(document, liquid_doc, input_lines, match)
          elsif match = current_line.match(GLOSSARIST_BLOCK_REGEX)
            process_glossarist_block(document, liquid_doc, input_lines, match)
          else
            @title_depth[:value] = current_line.sub(/ .*$/, "").size if /^==+ \S/.match?(current_line)
            liquid_doc.add_content(current_line)
          end
        end

        def process_dataset_tag(document, input_lines, liquid_doc, match)
          @seen_glossarist << "x"
          context_names = prepare_dataset_contexts(document, match[1])

          dataset_section = <<~TEMPLATE
            {% with_glossarist_context #{context_names} %}
            #{prepare_document(document, input_lines)}
            {% endwith_glossarist_context %}
          TEMPLATE

          liquid_doc.add_content(
            dataset_section,
            render: true,
          )
        end

        def process_glossarist_block(document, liquid_doc, input_lines, match)
          @seen_glossarist << "x"
          end_mark = input_lines.next
          path = relative_file_path(document, match[1])

          glossarist_params = prepare_glossarist_block_params(document, match)

          glossarist_section = <<~TEMPLATE.strip
            {% with_glossarist_context #{glossarist_params} %}
            #{prepare_document(document, input_lines, end_mark)}
            {% endwith_glossarist_context %}
          TEMPLATE

          liquid_doc.add_content(
            glossarist_section,
            render: true,
          )
        end

        def prepare_glossarist_block_params(document, match)
          path = relative_file_path(document, match[1])

          if match[2].strip.start_with?("filter")
            filters = match[2].split("=")[1..-1].join("=").strip
            context_name = match[3].strip
            "#{context_name}=#{path};#{filters}"
          else
            context_name = match[2].strip
            "#{context_name}=#{path}"
          end
        end

        def process_render_tag(liquid_doc, match)
          @seen_glossarist << "x"
          context_name, concept_name = match[1].split(",")

          liquid_doc.add_content(
            concept_template(context_name.strip, concept_name.strip),
          )
        end

        def process_import_tag(liquid_doc, match)
          @seen_glossarist << "x"
          context_name = match[1].strip
          dataset = @datasets[context_name.strip]

          liquid_doc.add_content(
            dataset.concepts.map do |concept_name, _concept|
              concept_template(context_name, concept_name)
            end.join("\n"),
          )
        end

        def process_bibliography(liquid_doc, match)
          @seen_glossarist << "x"
          dataset_name = match[1].strip
          dataset = @datasets[dataset_name]

          liquid_doc.add_content(
            dataset.concepts.map do |_concept_name, concept|
              concept_bibliography(concept)
            end.compact.sort.join("\n"),
          )
        end

        def process_bibliography_entry(liquid_doc, match)
          @seen_glossarist << "x"
          dataset_name, concept_name = match[1].split(",").map(&:strip)
          concept = @datasets[dataset_name][concept_name]

          liquid_doc.add_content(
            concept_bibliography(concept),
          )
        end

        def concept_bibliography(concept)
          bibliography = concept["eng"]["sources"].map do |source|
            ref = source["origin"]["ref"]

            next if @rendered_bibliographies[ref] || ref.nil? || ref.empty?

            @rendered_bibliographies[ref] = ref.gsub(/[ \/:]/, "_")
            "* [[[#{@rendered_bibliographies[ref]},#{ref}]]]"
          end.compact.join("\n")

          bibliography == "" ? nil : bibliography
        end

        def prepare_dataset_contexts(document, contexts)
          context_names = contexts.split(";").map do |context|
            context_name, file_path = context.split(":").map(&:strip)
            path = relative_file_path(document, file_path)

            dataset = ::Glossarist::ManagedConceptCollection.new
            dataset.load_from_files(path)
            @datasets[context_name] = Liquid::Drops::ConceptsDrop.new(dataset)

            "#{context_name}=#{path}"
          end

          context_names.join(",")
        end

        def relative_file_path(document, file_path)
          docfile_directory = File.dirname(
            document.attributes["docfile"] || ".",
          )
          document
            .path_resolver
            .system_path(file_path, docfile_directory)
        end

        def concept_template(dataset_name, concept_name)
          <<~CONCEPT_TEMPLATE
            #{"=" * (@title_depth[:value] + 1)} {{ #{dataset_name}['#{concept_name}'].term }}
            #{alt_terms(dataset_name, concept_name)}

            {{ #{dataset_name}['#{concept_name}']['eng'].definition[0].content }}

            #{examples(dataset_name, concept_name)}

            #{notes(dataset_name, concept_name)}

            #{sources(dataset_name, concept_name)}
          CONCEPT_TEMPLATE
        end

        def alt_terms(dataset_name, concept_name)
          concept = @datasets[dataset_name][concept_name]
          term_types = %w[preferred admitted deprecated]

          concept["eng"]["terms"][1..-1].map do |term|
            type = if term_types.include?(term["normative_status"])
                     term["normative_status"]
                   else
                     "alt"
                   end
            "#{type}:[#{term['designation']}]"
          end.join("\n")
        end

        def examples(dataset_name, concept_name)
          <<~EXAMPLES
            {% for example in #{dataset_name}['#{concept_name}']['eng'].examples %}
            [example]
            {{ example.content }}

            {% endfor %}
          EXAMPLES
        end

        def notes(dataset_name, concept_name)
          <<~NOTES
            {% for note in #{dataset_name}['#{concept_name}']['eng'].notes %}
            [NOTE]
            ====
            {{ note.content }}
            ====

            {% endfor %}
          NOTES
        end

        def sources(dataset_name, concept_name)
          <<~SOURCES
            {% for source in #{dataset_name}['#{concept_name}']['eng'].sources %}
            {%- if source.origin.ref == nil or source.origin.ref == '' %}{% continue %}{% endif %}
            [.source]
            <<{{ source.origin.ref | replace: ' ', '_' | replace: '/', '_' | replace: ':', '_' }},{{ source.origin.clause }}>>

            {% endfor %}
          SOURCES
        end
      end
    end
  end
end
