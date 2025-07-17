# frozen_string_literal: true

require "asciidoctor"

require "liquid"
require "asciidoctor/reader"
require "glossarist"
require "metanorma/plugin/glossarist/document"

module Metanorma
  module Plugin
    module Glossarist
      class DatasetPreprocessor < Asciidoctor::Extensions::Preprocessor
        GLOSSARIST_DATASET_REGEX = /^:glossarist-dataset:\s*(.*?)$/m.freeze
        GLOSSARIST_IMPORT_REGEX = /^glossarist::import\[(.*?)\]$/m.freeze
        GLOSSARIST_RENDER_REGEX = /^glossarist::render\[(.*?)\]$/m.freeze
        GLOSSARIST_BLOCK_REGEX = /^\[glossarist,(.+?),(.+?)\]$/m.freeze
        GLOSSARIST_BIBLIOGRAPHY_REGEX = /^glossarist::render_bibliography\[(.*?)\]$/m.freeze # rubocop:disable Layout/LineLength
        GLOSSARIST_BIBLIOGRAPHY_ENTRY_REGEX = /^glossarist::render_bibliography_entry\[(.*?)\]$/m.freeze # rubocop:disable Layout/LineLength

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
          @context_names = []
        end

        def process(document, reader)
          input_lines = reader.lines.to_enum
          @config[:file_system] = relative_file_path(document, "")
          processed_doc = prepare_document(document, input_lines)
          log(document, processed_doc.to_s) unless @seen_glossarist.empty?
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

        def prepare_document( # rubocop:disable Metrics/MethodLength
          document, input_lines, end_mark = nil,
          skip_dataset: false
        )
          liquid_doc = Document.new
          liquid_doc.file_system = @config[:file_system]

          loop do
            current_line = input_lines.next
            break if end_mark && current_line == end_mark

            if !(
              skip_dataset && current_line.start_with?(":glossarist-dataset:")
            )
              process_line(document, input_lines, current_line, liquid_doc)
            end
          end

          liquid_doc
        end

        def process_line( # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          document, input_lines, current_line, liquid_doc
        )
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
          elsif match = current_line.match(GLOSSARIST_BLOCK_REGEX)
            process_glossarist_block(document, liquid_doc, input_lines, match)
          else
            if /^==+ \S/.match?(current_line)
              @title_depth[:value] = current_line.sub(/ .*$/, "").size
            end
            liquid_doc.add_content(current_line)
          end
        end

        def process_dataset_tag(document, input_lines, liquid_doc, match)
          @seen_glossarist << "x"
          @context_names << prepare_dataset_contexts(document, match[1])
          @context_names.flatten!
          dataset_section = <<~TEMPLATE
            #{prepare_document(document, input_lines)}
          TEMPLATE

          liquid_doc.add_content(
            dataset_section,
            render: false,
          )
        end

        def process_glossarist_block(document, liquid_doc, input_lines, match)
          @seen_glossarist << "x"
          end_mark = input_lines.next

          glossarist_params, template =
            prepare_glossarist_block_params(document, match)
          glossarist_section = <<~TEMPLATE.strip
            {% with_glossarist_context #{glossarist_params} %}
            #{prepare_document(
              document, input_lines, end_mark,
              skip_dataset: true
            )}
            {% endwith_glossarist_context %}
          TEMPLATE

          options = { render: true }
          options[:template] = template if template

          liquid_doc.add_content(glossarist_section, options)
        end

        def prepare_glossarist_block_params(document, match) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          path = get_context_path(document, match[1])
          matched_arr = match[2].split(",").map(&:strip)
          # get the last element as context name
          context_name = matched_arr.last

          glossarist_block_params = []
          glossarist_block_params << "#{context_name}=#{path}"

          template = nil
          if matched_arr.size > 1
            filters_or_template = matched_arr[0..-2]
            filters_or_template.each do |item|
              if item.start_with?("filter=")
                filters = item.gsub(/^filter=/, "").strip
                glossarist_block_params << filters
              elsif item.start_with?("template=")
                template = relative_file_path(
                  document,
                  item.gsub(/^template=/, "").strip,
                )
              end
            end
          end

          [glossarist_block_params.join(";"), template]
        end

        def get_context_path(document, key) # rubocop:disable Metrics/MethodLength
          context_path = nil
          # try to get context_path from glossarist-dataset definition
          if @context_names && !@context_names.empty?
            context_names = @context_names.map(&:strip)
            context_path = context_names.find do |context|
              context_name, = context.split("=")
              context_name == key
            end
          end

          return context_path.split("=").last.strip if context_path

          relative_file_path(document, key)
        end

        def process_render_tag(liquid_doc, match)
          @seen_glossarist << "x"
          context_name, concept_name = match[1].split(",")

          liquid_doc.add_content(
            concept_template(context_name.strip, concept_name.strip),
          )
        end

        def process_import_tag(liquid_doc, match) # rubocop:disable Metrics/AbcSize
          @seen_glossarist << "x"
          context_name = match[1].strip
          dataset = @datasets[context_name]

          liquid_doc.add_content(
            dataset.map do |concept|
              concept_name = concept.data.localizations["eng"].data
                .terms[0].designation
              concept_template(context_name, concept_name)
            end.join("\n"),
          )
        end

        def process_bibliography(liquid_doc, match)
          @seen_glossarist << "x"
          dataset_name = match[1].strip
          dataset = @datasets[dataset_name]

          liquid_doc.add_content(
            dataset.map do |concept|
              concept_bibliography(concept)
            end.compact.sort.join("\n"),
          )
        end

        def process_bibliography_entry(liquid_doc, match)
          @seen_glossarist << "x"
          dataset_name, concept_name = match[1].split(",").map(&:strip)
          concept = get_concept(dataset_name, concept_name)
          bibliography = concept_bibliography(concept)
          if bibliography
            liquid_doc.add_content(bibliography)
          end
        end

        def concept_bibliography(concept) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          sources = concept.data.localizations["eng"].data.sources
          return nil if sources.nil? || sources.empty?

          bibliography = sources.map do |source|
            ref = source.origin.text
            next if @rendered_bibliographies[ref] || ref.nil? || ref.empty?

            @rendered_bibliographies[ref] = ref.gsub(/[ \/:]/, "_")
            "* [[[#{@rendered_bibliographies[ref]},#{ref}]]]"
          end.compact.join("\n")

          bibliography == "" ? nil : bibliography
        end

        def prepare_dataset_contexts(document, contexts)
          contexts.split(";").map do |context|
            context_name, file_path = context.split(":").map(&:strip)
            path = relative_file_path(document, file_path)

            dataset = ::Glossarist::ManagedConceptCollection.new
            dataset.load_from_files(path)
            @datasets[context_name] = dataset.map(&:to_liquid)

            "#{context_name}=#{path}"
          end
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
            #{'=' * (@title_depth[:value] + 1)} #{concept_title(dataset_name, concept_name)}
            #{alt_terms(dataset_name, concept_name)}

            #{concept_definition(dataset_name, concept_name)}

            #{examples(dataset_name, concept_name)}

            #{notes(dataset_name, concept_name)}

            #{sources(dataset_name, concept_name)}
          CONCEPT_TEMPLATE
        end

        def get_concept(dataset_name, concept_name)
          @datasets[dataset_name].find do |c|
            c.data.localizations["eng"]
              .data.terms[0]
              .designation == concept_name
          end
        end

        def concept_title(dataset_name, concept_name)
          concept = get_concept(dataset_name, concept_name)
          concept.data.localizations["eng"].data.terms[0].designation
        end

        def concept_definition(dataset_name, concept_name)
          concept = get_concept(dataset_name, concept_name)
          definition = concept.data.localizations["eng"].data
            .definition[0].content
          definition.to_s
        end

        def alt_terms(dataset_name, concept_name) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          concept = get_concept(dataset_name, concept_name)
          term_types = %w[preferred admitted deprecated]
          concept_terms = concept.data.localizations["eng"].data.terms

          concept_terms[1..-1].map do |term|
            type = if term_types.include?(term.normative_status)
                     term.normative_status
                   else
                     "alt"
                   end
            "#{type}:[#{term.designation}]"
          end.join("\n")
        end

        def examples(dataset_name, concept_name) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          concept = get_concept(dataset_name, concept_name)
          examples = concept.data.localizations["eng"].data.examples
          result = []

          examples.each do |example|
            content = <<~EXAMPLE
              [example]
              #{example.content}

            EXAMPLE
            result << content
          end

          result.join("\n")
        end

        def notes(dataset_name, concept_name) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          concept = get_concept(dataset_name, concept_name)
          notes = concept.data.localizations["eng"].data.notes
          result = []

          notes.each do |note|
            content = <<~NOTE
              [NOTE]
              ====
              #{note.content}
              ====

            NOTE
            result << content
          end

          result.join("\n")
        end

        def sources(dataset_name, concept_name) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          concept = get_concept(dataset_name, concept_name)
          sources = concept.data.localizations["eng"].data.sources
          result = []

          sources.each do |source|
            if source.origin.text &&
                source.origin.text != "" &&
                source.origin.locality.type == "clause"
              source_origin_text = source.origin.text
                .gsub(" ", "_")
                .gsub("/", "_")
                .gsub(":", "_")
              source_content = "#{source_origin_text}," \
                               "#{source.origin.locality.reference_from}"
              content = <<~SOURCES
                [.source]
                <<#{source_content}>>

              SOURCES
              result << content
            end
          end

          result.join("\n")
        end
      end
    end
  end
end
