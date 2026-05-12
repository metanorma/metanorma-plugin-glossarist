# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module Sanitize
        REF_REGEX = /{{([^,{}]+),([^}]+?)}}(.*)$/s
        XREF_REGEX = /<<([^,>\n]+?)(?:,[^>\n]*)?>>/

        def self.references(str)
          return str unless str&.match?(REF_REGEX)

          match = str.match(REF_REGEX)
          urn = Metanorma::Utils.to_ncname(match[1]).gsub(":", "_")
          "{{#{urn},#{match[2]}}}#{match[3]}"
        end

        def self.extract_xrefs(text)
          return [] unless text

          text.scan(XREF_REGEX).map(&:first).uniq
        end
      end
    end
  end
end
