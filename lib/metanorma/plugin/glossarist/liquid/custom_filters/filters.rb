# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module Liquid
        module CustomFilters
          module Filters
            def values(list)
              list.values
            end

            def terminological_data(term)
              result = []

              result << "&lt;#{term['usage_info']}&gt;" if term["usage_info"]
              result << extract_grammar_info(term)
              result << term["geographical_area"]&.upcase

              result.unshift(",") if result.compact.size.positive?

              result.compact.join(" ")
            end

            def extract_grammar_info(term)
              return unless term["grammar_info"]

              grammar_info = []

              term["grammar_info"].each do |info|
                grammar_info << info["gender"]&.join(", ")
                grammar_info << info["number"]&.join(", ")
                grammar_info << extract_parts_of_speech(info)
              end

              grammar_info.join(" ")
            end
          end
        end
      end
    end
  end
end
