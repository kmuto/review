# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class DocumentNode < Node
      attr_accessor :title, :chapter

      def initialize(location: nil, title: nil, chapter: nil, **kwargs)
        super(location: location, **kwargs)
        @title = title
        @chapter = chapter
      end

      def to_h
        super.merge(
          title: title
        )
      end

      private

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children.any?
        hash[:title] = title
        hash
      end
    end
  end
end
