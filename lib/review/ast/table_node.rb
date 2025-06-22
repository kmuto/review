# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class TableNode < Node
      attr_accessor :caption, :headers, :rows, :table_type, :metric

      def initialize(location: nil, id: nil, caption: nil, headers: [], rows: [], table_type: :table, metric: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @caption = CaptionNode.parse(caption, location: location)
        @headers = headers || []
        @rows = rows || []
        @table_type = table_type # :table, :emtable, :imgtable
        @metric = metric
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      def to_h
        result = super.merge(
          caption: caption&.to_h,
          headers: headers,
          rows: rows,
          table_type: table_type
        )
        result[:metric] = metric if metric
        result
      end

      protected

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        hash[:table_type] = table_type
        # For backward compatibility, serialize caption as its children array
        hash[:caption] = @caption ? @caption.serialize_to_hash(options) : nil
        hash[:headers] = headers if headers&.any?
        hash[:rows] = rows if rows&.any?
        hash[:metric] = metric if metric
        hash
      end
    end
  end
end
