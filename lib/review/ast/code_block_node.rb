# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class CodeBlockNode < Node
      attr_accessor :lang, :id, :caption, :lines, :line_numbers

      def initialize(location: nil, lang: nil, id: nil, caption: nil, lines: [], line_numbers: false, **kwargs)
        super(location: location, id: id, **kwargs)
        @lang = lang
        @id = id
        @caption = caption || [] # caption is now an array of nodes
        @lines = lines
        @line_numbers = line_numbers
      end

      def to_h
        super.merge(
          lang: lang,
          id: id,
          caption: caption.is_a?(Array) ? caption.map(&:to_h) : caption,
          lines: lines,
          line_numbers: line_numbers
        )
      end

      protected

      def serialize_properties(hash, options)
        hash[:children] = []
        hash[:lang] = lang
        hash[:id] = id
        hash[:caption] = caption.is_a?(Array) ? caption.map { |child| child.serialize_to_hash(options) } : caption
        hash[:lines] = lines
        hash[:line_numbers] = line_numbers
        hash
      end
    end
  end
end
