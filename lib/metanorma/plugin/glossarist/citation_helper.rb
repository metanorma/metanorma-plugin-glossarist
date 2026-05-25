# frozen_string_literal: true

module Metanorma
  module Plugin
    module Glossarist
      module CitationHelper
        def citation_ref_label(citation)
          citation&.label
        end
      end
    end
  end
end
