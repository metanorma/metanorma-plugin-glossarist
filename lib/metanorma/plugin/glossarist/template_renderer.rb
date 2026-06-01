# frozen_string_literal: true

require "liquid"

module Metanorma
  module Plugin
    module Glossarist
      class TemplateRenderer
        TEMPLATES_DIR = File.join(File.dirname(__FILE__), "liquid_templates")
        DEFAULT_TEMPLATE = File.join(TEMPLATES_DIR, "_concept.liquid")

        def initialize(file_system:, lang: "eng")
          @file_system = file_system
          @lang = lang
          @template_cache = {}
        end

        def render_concepts(concepts, depth:, anchor_prefix: nil)
          tree = build_concept_tree(concepts)
          parts = tree.map { |c| render_tree_node(c, depth, anchor_prefix) }
          normalize_whitespace(parts.join("\n\n"))
        end

        def render_concept(concept, depth:, anchor_prefix: nil)
          l10n = concept.localization(@lang)
          context = {
            "concept" => concept.to_liquid,
            "l10n" => l10n&.to_liquid,
            "depth_marker" => "=" * (depth + 1),
            "anchor" => build_anchor(concept.data.id.to_s, anchor_prefix),
          }
          template_content = cached_template(concept)
          rendered = render_template(template_content, context)
          normalize_whitespace(rendered)
        end

        private

        def cached_template(concept)
          version = concept.schema_version
          @template_cache[version] ||= begin
            path = File.join(TEMPLATES_DIR, "_concept_#{version}.liquid")
            File.exist?(path) ? File.read(path) : File.read(DEFAULT_TEMPLATE)
          end
        end

        def render_tree_node((concept, children), depth, anchor_prefix)
          result = render_concept(concept, depth: depth, anchor_prefix: anchor_prefix)
          children.each do |child_node|
            result += "\n" + render_tree_node(child_node, depth + 1, anchor_prefix)
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
          concepts.map { |c| [c, build_tree_nodes(children_of[concept_id(c)], children_of)] }
        end

        def concept_id(concept)
          concept.data.id.to_s
        end

        def find_parent_id(concept)
          concept.data.related&.find { |r| r.type == "broader" }&.ref&.id&.to_s
        end

        def build_anchor(id, prefix)
          anchor = prefix ? "#{prefix}#{id}" : id
          anchor.match?(/\A\d/) ? anchor : Metanorma::Utils.to_ncname(anchor.gsub(":", "_"))
        end

        def render_template(content, assigns)
          include_paths = [TEMPLATES_DIR, @file_system].compact
          template = ::Liquid::Template.parse(content)
          template.registers[:file_system] = Liquid::LocalFileSystem.new(
            include_paths, ["%s.liquid", "_%s.liquid"]
          )
          rendered = template.render(assigns)
          raise template.errors.first.cause if template.errors.any?

          rendered
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
