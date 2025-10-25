# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class DocumentNode < Node
      attr_reader :chapter
      attr_accessor :indexes_generated

      def initialize(location: nil, chapter: nil, **kwargs)
        super(location: location, **kwargs)
        @chapter = chapter
        @indexes_generated = false
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children.any?
        hash
      end
    end
  end
end
