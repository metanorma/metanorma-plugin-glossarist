# frozen_string_literal: true

# Includes Lutaml::Model::Liquid::IndexedAccess into Glossarist collection
# classes so that their auto-generated Liquid drops support bracket access
# (e.g., +localizations['eng']+, +definition[0]+).
#
# Glossarist collections support +self[key]+ but do not yet include
# IndexedAccess in their published gem. Once they do, this file can be
# removed.
#
# @see Lutaml::Model::Liquid::IndexedAccess (lutaml-model >= 0.8.15)
# @see https://github.com/lutaml/lutaml-model/pull/705
%w[
  Glossarist::Collections::LocalizationCollection
  Glossarist::Collections::DetailedDefinitionCollection
  Glossarist::Collections::ConceptSourceCollection
].each do |class_name|
  parts = class_name.split("::")
  const = parts.reduce(Object) { |mod, name| mod.const_get(name) }
  const.include(Lutaml::Model::Liquid::IndexedAccess) unless const.include?(Lutaml::Model::Liquid::IndexedAccess)
rescue NameError
  # Collection class not yet defined — skip
end
