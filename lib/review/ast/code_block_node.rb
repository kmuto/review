# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class CodeBlockNode < Node
      attr_accessor :lang, :caption, :lines, :line_numbers, :code_type

      def initialize(location: nil, lang: nil, id: nil, caption: nil, lines: [], line_numbers: false, code_type: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @lang = lang
        @caption = caption || [] # caption is now an array of nodes
        @lines = lines
        @line_numbers = line_numbers
        @code_type = code_type
      end

      def to_h
        result = super.merge(
          lang: lang,
          caption: caption.is_a?(Array) ? caption.map(&:to_h) : caption,
          lines: lines,
          line_numbers: line_numbers
        )
        result[:code_type] = code_type if code_type
        result
      end

      protected

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        hash[:lang] = lang
        hash[:caption] = caption.is_a?(Array) ? caption.map { |child| child.serialize_to_hash(options) } : caption
        hash[:lines] = lines
        hash[:line_numbers] = line_numbers
        hash[:code_type] = code_type if code_type
        hash
      end
    end
  end
end
