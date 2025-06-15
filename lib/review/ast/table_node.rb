# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :id, :caption, :headers, :rows

      def initialize(location: nil, id: nil, caption: nil, headers: [], rows: [], **kwargs)
        super(location: location, **kwargs)
        @id = id
        @caption = caption || []
        @headers = headers || []
        @rows = rows || []
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
        hash[:id] = id if id
        hash[:caption] = caption if caption
        hash[:headers] = headers if headers && headers.any?
        hash[:rows] = rows if rows && rows.any?
        hash
      end
    end
  end
end
