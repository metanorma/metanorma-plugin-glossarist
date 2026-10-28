# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class TemplateRenderer
        DEFAULT_TEMPLATE = File.join(TEMPLATES_DIR, "_concept.liquid")

        def initialize(file_system:, lang: "eng")
          @file_system = file_system
          @lang = lang
        end

        def render_concepts(concepts, depth:, anchor_prefix: nil,
                            non_verbal: nil)
          tree = build_concept_tree(concepts)
          parts = tree.map do |node|
            render_tree_node(node, depth, anchor_prefix, non_verbal)
          end
          normalize_whitespace(parts.join("\n\n"))
        end

        def render_concept(concept, depth:, anchor_prefix: nil,
                           non_verbal: nil)
          l10n = concept.localization(@lang)
          context = {
            "concept" => concept.to_liquid,
            "l10n" => l10n&.to_liquid,
            "depth_marker" => "=" * (depth + 1),
            "anchor" => build_anchor(concept.data.id.to_s, anchor_prefix),
          }
          rendered = render_template(default_template_source, context)
          if non_verbal
            rendered += "\n\n#{non_verbal.render_concept_refs(concept)}"
          end
          normalize_whitespace(rendered)
        end

        private

        # The default template is read once per process: render_concept
        # runs per concept, and re-reading the file per concept dominated
        # I/O on large vocabularies.
        def default_template_source
          @default_template_source ||= File.read(DEFAULT_TEMPLATE)
        end

        def render_tree_node((concept, children), depth, anchor_prefix,
                             non_verbal)
          result = render_concept(concept, depth: depth,
                                           anchor_prefix: anchor_prefix,
                                           non_verbal: non_verbal)
          children.each do |child_node|
            result += "\n" + render_tree_node(child_node, depth + 1,
                                              anchor_prefix, non_verbal)
          end
          result
        end

        def build_concept_tree(concepts)
          concept_map = concepts.to_h { |c| [concept_id(c), c] }
          children_of = Hash.new { |h, k| h[k] = [] }
          roots = []

          concepts.each do |c|
            parent_id = find_parent_id(c)
            if parent_id && concept_map[parent_id]
              children_of[parent_id] << c
            else
              roots << c
            end
          end

          build_tree_nodes(roots, children_of)
        end

        def build_tree_nodes(concepts, children_of)
          concepts.map do |c|
            [c, build_tree_nodes(children_of[concept_id(c)], children_of)]
          end
        end

        def concept_id(concept)
          concept.data.id.to_s
        end

        def find_parent_id(concept)
          related = concept.data.related || concept.related
          related&.find { |r| r.type == "broader" }&.ref&.id&.to_s
        end

        def build_anchor(id, prefix)
          anchor = prefix ? "#{prefix}#{id}" : id
          if anchor.match?(/\A\d/)
            anchor
          else
            Metanorma::Utils.to_ncname(anchor.gsub(
                                         ":", "_"
                                       ))
          end
        end

        def render_template(content, assigns)
          LiquidRendering.render(
            content,
            include_paths: [TEMPLATES_DIR, @file_system].compact,
            assigns: assigns,
          )
        end

        def normalize_whitespace(text)
          text.gsub(/\n{3,}/, "\n\n")
            .gsub(/([^\]\n])\n(={2,6} )/, "\\1\n\n\\2")
            .strip
        end
      end
    end
  end
end
