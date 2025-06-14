# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class CodeBlockNode < Node
      attr_accessor :lang, :id, :caption, :lines, :line_numbers

      def initialize(location = nil)
        super
        @lang = nil
        @id = nil
        @caption = nil
        @lines = []
        @line_numbers = false
      end

      def to_h
        super.merge(
          lang: lang,
          id: id,
          caption: caption,
          lines: lines,
          line_numbers: line_numbers
        )
      end

      protected

      def serialize_properties(hash, _options)
        hash[:children] = []
        hash[:lang] = lang
        hash[:id] = id
        hash[:caption] = caption
        hash[:lines] = lines
        hash[:line_numbers] = line_numbers
        hash
      end
    end
  end
end
