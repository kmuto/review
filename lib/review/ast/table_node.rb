# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :id, :caption, :headers, :rows

      def initialize(location = nil)
        super
        @id = nil
        @caption = nil
        @headers = []
        @rows = []
      end

      def to_h
        super.merge(
          id: id,
          caption: caption,
          headers: headers,
          rows: rows
        )
      end

      protected

      def serialize_properties(hash, _options)
        hash[:id] = id
        hash[:caption] = caption
        hash[:headers] = headers
        hash[:rows] = rows
        hash
      end
    end
  end
end
