# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class DocumentNode < Node
      attr_accessor :title

      def initialize(location: nil, title: nil, **kwargs)
        super(location: location, **kwargs)
        @title = title
      end

      def to_h
        super.merge(
          title: title
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:children] = children.map { |child| child.serialize_to_hash(options) } if children.any?
        hash[:title] = title
        hash
      end
    end
  end
end
