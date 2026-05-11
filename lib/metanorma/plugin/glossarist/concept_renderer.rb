# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptRenderer
        TERM_TYPES = %w[preferred admitted deprecated].freeze

        def initialize(concept, depth:, anchor_prefix: nil)
          @concept = concept
          @depth = depth
          @anchor_prefix = anchor_prefix
        end

        def render
          sections = [concept_header]
          sections << alt_terms_section
          sections << definition_section
          sections << examples_section
          sections << notes_section
          sections << sources_section
          sections.compact.join("\n\n")
        end

        private

        def eng_l10n
          @eng_l10n ||= @concept.localization("eng")
        end

        def concept_header
          "[[#{anchor_id}]]\n#{heading_line}"
        end

        def anchor_id
          id = "#{@anchor_prefix}#{@concept.data.id}"
          id.match?(/\A\d/) ? id : Metanorma::Utils.to_ncname(id.gsub(":", "_"))
        end

        def heading_line
          "#{'=' * (@depth + 1)} #{term_designation}"
        end

        def term_designation
          eng_l10n.terms.first&.designation.to_s
        end

        def alt_terms_section
          terms = eng_l10n.terms[1..].map do |term|
            type = TERM_TYPES.include?(term.normative_status) ? term.normative_status : "alt"
            "#{type}:[#{term.designation}]"
          end
          terms.empty? ? nil : terms.join("\n")
        end

        def definition_section
          content = eng_l10n.definition.first&.content
          return nil unless content

          Sanitize.references(content.to_s)
        end

        def examples_section
          examples = eng_l10n.examples.map do |example|
            "[example]\n#{Sanitize.references(example.content.to_s)}"
          end
          examples.empty? ? nil : examples.join("\n")
        end

        def notes_section
          notes = eng_l10n.notes.map do |note|
            "[NOTE]\n====\n#{Sanitize.references(note.content.to_s)}\n===="
          end
          notes.empty? ? nil : notes.join("\n")
        end

        def sources_section
          sources = eng_l10n.sources.filter_map do |source|
            next if source.origin&.text.nil? || source.origin.text.empty?
            next unless source.origin.locality&.type == "clause"

            ref = source.origin.text.gsub(%r{[ /:]}, "_")
            clause = source.origin.locality.reference_from
            "[.source]\n<<#{ref},#{clause}>>"
          end
          sources.empty? ? nil : sources.join("\n")
        end
      end
    end
  end
end
