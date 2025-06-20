# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :caption, :headers, :rows, :table_type, :metric

      def initialize(location: nil, id: nil, caption: nil, headers: [], rows: [], table_type: :table, metric: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption = caption || []
        @headers = headers || []
        @rows = rows || []
        @table_type = table_type # :table, :emtable, :imgtable
        @metric = metric
      end

      def to_h
        result = super.merge(
          caption: caption,
          headers: headers,
          rows: rows,
          table_type: table_type
        )
        result[:metric] = metric if metric
        result
      end

      protected

      def serialize_properties(hash, _options)
        hash[:table_type] = table_type
        hash[:caption] = caption if caption
        hash[:headers] = headers if headers && headers.any?
        hash[:rows] = rows if rows && rows.any?
        hash[:metric] = metric if metric
        hash
      end
    end
  end
end
