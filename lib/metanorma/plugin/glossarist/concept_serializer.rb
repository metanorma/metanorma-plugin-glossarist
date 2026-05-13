# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      class ConceptSerializer
        def initialize(concept)
          @concept = concept
        end

        def to_h
          data = @concept.data.to_hash
          data["localizations"] = localizations_hash unless @concept.localizations.empty?
          { "data" => data.compact }
        end

        private

        def localizations_hash
          @concept.localizations.to_h do |l10n|
            [l10n.language_code, l10n.to_hash]
          end
        end
      end
    end
  end
end
