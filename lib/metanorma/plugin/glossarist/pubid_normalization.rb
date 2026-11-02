# frozen_string_literal: true

require "pubid"

module Metanorma
  module Plugin
    module Glossarist
      # pubid is the SSOT for document identifiers: where a citation or
      # bibliography reference is a supported pubid form, display text
      # renders through pubid's canonical form; anything else (lowercase
      # variants pending metanorma/pubid#644, free text) stays as
      # written. Display normalisation only — no validity judgments.
      module PubidNormalization
        def normalized_reference(ref)
          return nil if ref.nil?

          Pubid.parse(ref.to_s).to_s
        rescue Pubid::Errors::Error
          ref
        end
      end
    end
  end
end
