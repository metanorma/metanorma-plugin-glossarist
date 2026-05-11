# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module Sanitize
        REF_REGEX = /{{([^,]{1,500}),([^\}]{1,500})}}(.*?)$/s

        def self.references(str)
          return str unless str&.match?(REF_REGEX)

          match = str.match(REF_REGEX)
          urn = Metanorma::Utils.to_ncname(match[1]).gsub(":", "_")
          "{{#{urn},#{match[2]}}}#{match[3]}"
        end
      end
    end
  end
end
