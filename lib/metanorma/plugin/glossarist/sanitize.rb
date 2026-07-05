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
            urn = Metanorma::Utils.to_ncname(m[1]).gsub(":", "_")
            "{{#{urn},#{m[2]}}}#{m[3]}"
          end
        end
      end
    end
  end
end
