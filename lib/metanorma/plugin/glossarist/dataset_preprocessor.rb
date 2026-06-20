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
        IMPORT_SECTIONS_REGEX = /^glossarist::import_sections\[(.*?)\]$/m
        RENDER_REGEX = /^glossarist::render\[(.*?)\]$/m
        BLOCK_REGEX = /^\[glossarist,(.+?),(.+?)\]$/m
        BIBLIOGRAPHY_REGEX = /^glossarist::render_bibliography\[(.*?)\]$/m
        BIBLIOGRAPHY_ENTRY_REGEX = /^glossarist::render_bibliography_entry\[(.*?)\]$/m
        NON_VERBAL_REGEX = /^glossarist::render_(figures|tables|formulas)\[(.*?)\]$/m

        BIB_ANCHOR_REGEX = /^\*\s*\[\[\[([^,]+)/

        def initialize(config = {})
          super
          @config = config
        end

        def process(document, reader)
          input_lines = reader.lines.to_enum
          @config[:file_system] = relative_file_path(document, "")
          @registry = DatasetRegistry.new
          @renderer = TemplateRenderer.new(file_system: @config[:file_system])
          @rendered_concepts = []
          @title_depth = 2
          @existing_bib_anchors = []
          @seen_glossarist = false

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
          liquid_doc.registry = @registry

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
          handler = directive_handler(current_line)
          if handler
            handler.call(document, input_lines, liquid_doc)
          else
            handle_plain_line(current_line, liquid_doc)
          end
        end

        # Returns a callable that handles the directive on +line+, or nil
        # for plain content. Keeping the dispatch table small (regex →
        # block) lets us add a new directive by appending one entry.
        def directive_handler(line)
          if (m = line.match(DATASET_ATTR_REGEX))
            ->(doc, lines, ldoc) { process_dataset_tag(doc, lines, ldoc, m) }
          elsif (m = line.match(RENDER_REGEX))
            ->(_, _, ldoc) { process_render_tag(ldoc, m) }
          elsif (m = line.match(IMPORT_SECTIONS_REGEX))
            ->(doc, _, ldoc) { process_import_sections_tag(doc, ldoc, m) }
          elsif (m = line.match(IMPORT_REGEX))
            ->(_, _, ldoc) { process_import_tag(ldoc, m) }
          elsif (m = line.match(BIBLIOGRAPHY_REGEX))
            ->(doc, _, ldoc) { process_bibliography(doc, ldoc, m) }
          elsif (m = line.match(BIBLIOGRAPHY_ENTRY_REGEX))
            ->(doc, _, ldoc) { process_bibliography_entry(doc, ldoc, m) }
          elsif (m = line.match(NON_VERBAL_REGEX))
            ->(_, _, ldoc) { process_non_verbal(ldoc, m) }
          elsif (m = line.match(BLOCK_REGEX))
            ->(doc, lines, ldoc) { process_glossarist_block(doc, ldoc, lines, m) }
          end
        end

        def handle_plain_line(current_line, liquid_doc)
          if /^==+ \S/.match?(current_line)
            @title_depth = current_line.sub(/ .*$/, "").size
          end
          if (match = current_line.match(BIB_ANCHOR_REGEX))
            @existing_bib_anchors << match[1]
          end
          liquid_doc.add_content(current_line)
        end

        def process_dataset_tag(document, input_lines, liquid_doc, match)
          @seen_glossarist = true
          @registry.register(document, match[1])
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
          @registry.context_path(key) || relative_file_path(document, key)
        end

        def process_render_tag(liquid_doc, match)
          @seen_glossarist = true
          matches = match[1].split(",").map(&:strip)
          context_name = matches[0]
          concept_name = matches[1]
          options = parse_options(matches[2..])

          concept = @registry.find_concept(context_name, concept_name)
          return unless concept

          @rendered_concepts << concept
          renderer = @renderer
          rendered = renderer.render_concept(concept,
                                             depth: @title_depth,
                                             anchor_prefix: options["anchor-prefix"],
                                             non_verbal: non_verbal_for(context_name))
          liquid_doc.add_content("\n#{rendered}")
        end

        RENDER_OPTIONS = %w[anchor-prefix].freeze

        def process_import_tag(liquid_doc, match)
          @seen_glossarist = true
          matches = match[1].split(",").map(&:strip)
          context_name = matches[0]
          options = parse_options(matches[1..])
          dataset = @registry.resolve_dataset(nil, context_name)
          return unless dataset

          filter_options = options.except(*RENDER_OPTIONS)
          concepts = ConceptFilter.new(filter_options)
            .apply(dataset, register: @registry.register_for(context_name))
          concepts = concepts.select(&:default_designation)
          @rendered_concepts.concat(concepts)
          renderer = @renderer
          rendered = renderer.render_concepts(concepts,
                                              depth: @title_depth,
                                              anchor_prefix: options["anchor-prefix"],
                                              non_verbal: non_verbal_for(context_name))
          liquid_doc.add_content("\n#{rendered}")
        end

        def process_import_sections_tag(_document, liquid_doc, match)
          @seen_glossarist = true
          matches = match[1].split(",").map(&:strip)
          context_name = matches[0]
          options = parse_options(matches[1..])

          register = @registry.register_for(context_name)
          sections = register&.sections
          return unless sections && !sections.empty?

          dataset = @registry.resolve_dataset(nil, context_name)
          return unless dataset

          parts = render_sections(dataset, register, sections, context_name, options)
          liquid_doc.add_content("\n#{parts.join("\n\n")}")
        end

        def render_sections(dataset, register, sections, context_name, options)
          section_filter = SectionFilter.new(
            exclude: (options["section_exclude"] || "").split("|"),
            include: (options["section_include"] || "").split("|"),
          )
          filtered = section_filter.apply(sections)
          renderer = SectionRenderer.new(
            dataset: dataset,
            register: register,
            renderer: @renderer,
            depth: @title_depth,
            sort_by: options["sort_by"] || SectionRenderer::DEFAULT_SORT_BY,
            anchor_prefix: options["anchor-prefix"],
            non_verbal: non_verbal_for(context_name),
          )
          renderer.render(filtered) do |concepts|
            @rendered_concepts.concat(concepts)
          end
        end

        # Builds a NonVerbalRenderer scoped to a dataset context, or
        # returns nil if the dataset has no figures/tables/formulas. The
        # resulting renderer is passed through to TemplateRenderer and
        # SectionRenderer so concept-attached refs render as AsciiDoc
        # blocks alongside the concept body.
        def non_verbal_for(context_name)
          collections = @registry.non_verbal_collections(context_name)
          return nil if collections.empty?

          NonVerbalRenderer.new(collections: collections)
        end

        def process_bibliography(document, liquid_doc, match)
          @seen_glossarist = true
          dataset_name = match[1].strip
          concepts = if @rendered_concepts.empty?
                       @registry.resolve_dataset(
                         document, dataset_name
                       )
                     else
                       @rendered_concepts
                     end
          return unless concepts && !concepts.empty?

          renderer = BibliographyRenderer.new(
            existing_anchors: @existing_bib_anchors,
            bibliography: @registry.bibliography_for(dataset_name),
          )
          liquid_doc.add_content(renderer.render_all(concepts))
        end

        def process_bibliography_entry(document, liquid_doc, match)
          @seen_glossarist = true
          dataset_name, concept_name = match[1].split(",").map(&:strip)
          concept = @registry.find_concept(dataset_name, concept_name, document)
          return unless concept

          renderer = BibliographyRenderer.new(
            existing_anchors: @existing_bib_anchors,
            bibliography: @registry.bibliography_for(dataset_name),
          )
          entry = renderer.render_entry(concept)
          liquid_doc.add_content(entry) if entry
        end

        # Renders all dataset-level entities of a non-verbal kind
        # (figures, tables, formulas) as AsciiDoc blocks. The directive
        # shape is +glossarist::render_<kind>[dataset]+.
        def process_non_verbal(liquid_doc, match)
          @seen_glossarist = true
          kind = :"#{match[1]}"
          dataset_name = match[2].strip
          collection = @registry.non_verbal_collection(dataset_name, kind)
          return unless collection

          renderer = NonVerbalRenderer.new(collections: { kind => collection })
          rendered = renderer.render_kind(kind)
          liquid_doc.add_content("\n#{rendered}") unless rendered.empty?
        end

        def relative_file_path(document, file_path)
          return file_path if File.absolute_path?(file_path)

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
