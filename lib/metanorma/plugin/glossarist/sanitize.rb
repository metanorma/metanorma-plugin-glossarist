# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module Sanitize
        REF_REGEX = /{{(urn:[^,{}]+),([^}]+?)}}(.*)$/m

        def self.references(str)
          return str unless str&.match?(REF_REGEX)

          str.gsub(REF_REGEX) do
            m = Regexp.last_match
            # term/tech citations resolve against the document's own
            # anchors at render time, where the anchor prefix is known
            # (see resolve_urn_citations) -- pass the colon form through
            # to it. Everything else keeps the legacy ncname form.
            next m[0] if m[1].match?(URN_SEGMENT_RX)

            urn = Metanorma::Utils.to_ncname(m[1]).gsub(":", "_")
            "{{#{urn},#{m[2]}}}#{m[3]}"
          end
        end

        # A `{{urn:<base>:term:<id>,display}}` (or `:tech:`) citation names
        # a concept in one of the document's own datasets. Rewrite it to
        # the termbase xref form the converter resolves against the
        # rendered `[[<id>]]` anchors, instead of leaving a raw URN that
        # the term lookup cannot match. Citations without a term/tech
        # segment (e.g. `{{bib:...}}`) are left untouched.
        URN_CITATION_RX = /\{\{(urn:[^,{}]+),([^}]+?)\}\}/.freeze
        URN_SEGMENT_RX = /:(?:term|tech):/.freeze

        def self.resolve_urn_citations(str, anchor_prefix = nil)
          return str unless str&.include?("{{")

          resolve = lambda do |id, display|
            anchor = anchor_prefix ? "#{anchor_prefix}#{id}" : id
            anchor = Metanorma::Utils.to_ncname(anchor.gsub(":", "_"))
            "<<#{anchor},#{display}>>"
          end

          str.gsub(URN_CITATION_RX) do
            m = Regexp.last_match
            id = m[1].sub(/\A.*:(?:term|tech):/, "")
            next m[0] if id.empty?

            resolve.call(id, m[2])
          end
        end
      end
    end
  end
end
