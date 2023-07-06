module Liquid
  module CustomBlocks
    class WithGlossaristContext < Block
      def initialize(tag_name, markup, tokens)
        super

        @contexts = []
        @filters = {}

        contexts, filters = markup.split(";", 2)

        if filters && !filters.empty?
          filters.strip.gsub(/^['"]|['"]$/, "").split(";").each do |filter|
            property, value = filter.split("=")

            @filters[property] = value
          end
        end

        contexts.split(",").each do |context|
          context_name, file_path = context.split("=").map(&:strip)

          @contexts << {
            name: context_name,
            file_path: file_path,
          }
        end
      end

      def load_collection(folder_path)
        @@collections ||= {}

        return @@collections[folder_path] if @@collections[folder_path]

        collection = ::Glossarist::ManagedConceptCollection.new
        collection.load_from_files(folder_path)
        @@collections[folder_path] = collection
      end

      def render(context)
        @contexts.each do |local_context|
          context_file = local_context[:file_path].strip
          collection = load_collection(context_file)

          context[local_context[:name]] = Liquid::Drops::ConceptsDrop.new(collection, @filters)
        end

        super
      end
    end
  end
end
