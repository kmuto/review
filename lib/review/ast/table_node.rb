# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :id, :caption, :headers, :rows

      def initialize(location: nil, id: nil, caption: nil, headers: [], rows: [], **kwargs)
        super(location: location, id: id, **kwargs)
        @id = id
        @caption = caption || [] # caption is now an array of nodes
        @headers = headers
        @rows = rows
      end

      def to_h
        super.merge(
          id: id,
          caption: caption.is_a?(Array) ? caption.map(&:to_h) : caption,
          headers: headers,
          rows: rows
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:id] = id
        hash[:caption] = caption.is_a?(Array) ? caption.map { |child| child.serialize_to_hash(options) } : caption
        hash[:headers] = headers
        hash[:rows] = rows
        hash
      end
    end
  end
end
