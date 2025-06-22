# frozen_string_literal: true

require 'review/ast/node'
require 'review/ast/caption_node'

module ReVIEW
  module AST
    class CodeBlockNode < Node
      attr_accessor :lang, :caption, :lines, :line_numbers, :code_type, :processed_lines, :original_text

      def initialize(location: nil, lang: nil, id: nil, caption: nil, lines: [], line_numbers: false, code_type: nil, processed_lines: nil, original_text: nil, **kwargs)
        super(location: location, id: id, original_text: original_text, **kwargs)
        @lang = lang
        @caption = CaptionNode.parse(caption, location: location)
        @lines = lines
        @line_numbers = line_numbers
        @code_type = code_type
        @processed_lines = processed_lines # Array of AST nodes with inline processing
      end

      # Get lines content appropriate for the given builder
      def get_lines_for_builder(builder_needs_inline: false)
        if builder_needs_inline && @processed_lines
          @processed_lines
        else
          @lines
        end
      end

      # Get raw content (original text or lines)
      def raw_content
        @original_text || (@lines ? @lines.join("\n") : '')
      end

      # Get caption text for legacy Builder compatibility
      def caption_markup_text
        @caption&.to_text || ''
      end

      def to_h
        result = super.merge(
          lang: lang,
          caption: caption&.to_h,
          lines: lines,
          line_numbers: line_numbers
        )
        result[:code_type] = code_type if code_type
        result
      end

      private

      protected

      def serialize_properties(hash, options)
        hash[:id] = id if id && !id.empty?
        hash[:lang] = lang
        # For backward compatibility, serialize caption as its children array
        hash[:caption] = @caption&.serialize_to_hash(options)
        hash[:lines] = lines
        hash[:line_numbers] = line_numbers
        hash[:code_type] = code_type if code_type
        hash
      end
    end
  end
end
