# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    # MinicolumnNode - Represents minicolumn blocks (note, memo, tip, etc.)
    class MinicolumnNode < Node
      attr_accessor :minicolumn_type, :caption

      def initialize(location: nil, minicolumn_type: nil, caption: nil, **kwargs)
        super(location: location, **kwargs)
        @minicolumn_type = minicolumn_type # :note, :memo, :tip, :info, :warning, :important, :caution, :notice
        @caption = caption ? CaptionNode.parse(caption, location: location) : nil
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      def to_h
        result = super.merge(
          minicolumn_type: minicolumn_type
        )
        result[:caption] = caption&.to_h if @caption
        result
      end

      private

      protected

      def serialize_properties(hash, options)
        hash[:minicolumn_type] = minicolumn_type
        hash[:caption] = @caption ? @caption.serialize_to_hash(options) : nil if @caption
        if options.include_empty_arrays || children.any?
          hash[:children] = children.map { |child| child.serialize_to_hash(options) }
        end
        hash
      end
    end
  end
end
