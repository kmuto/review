# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class DocumentNode < Node
      attr_reader :chapter

      def initialize(location:, chapter: nil, **kwargs)
        super(location: location, **kwargs)
        @chapter = chapter
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children.any?
        hash
      end
    end
  end
end
