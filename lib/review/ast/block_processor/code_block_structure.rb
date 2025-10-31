# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class BlockProcessor
      # Data structure representing code block structure (intermediate representation)
      # This class represents the result of parsing code block command and arguments
      # into a structured format. It serves as an intermediate layer between
      # block command context and AST nodes.
      class CodeBlockStructure
        attr_reader :id, :caption_node, :lang, :line_numbers, :code_type, :lines, :original_text

        # Factory method to create CodeBlockStructure from context and config
        # @param context [BlockContext] Block context
        # @param config [Hash] Code block configuration
        # @return [CodeBlockStructure] Parsed code block structure
        # @raise [CompileError] If configuration is invalid
        def self.from_context(context, config)
          id = context.arg(config[:id_index])
          caption_node = context.process_caption(context.args, config[:caption_index])
          lang = context.arg(config[:lang_index]) || config[:default_lang]
          line_numbers = config[:line_numbers] || false
          lines = context.lines || []
          original_text = lines.join("\n")

          new(
            id: id,
            caption_node: caption_node,
            lang: lang,
            line_numbers: line_numbers,
            code_type: context.name,
            lines: lines,
            original_text: original_text
          )
        end

        def initialize(id:, caption_node:, lang:, line_numbers:, code_type:, lines:, original_text:)
          @id = id
          @caption_node = caption_node
          @lang = lang
          @line_numbers = line_numbers
          @code_type = code_type
          @lines = lines
          @original_text = original_text
        end

        # Check if this code block has an ID (list-style blocks)
        # @return [Boolean] True if has ID
        def id?
          !id.nil? && !id.empty?
        end

        # Check if this code block should show line numbers
        # @return [Boolean] True if line numbers should be shown
        def numbered?
          line_numbers
        end

        # Check if this code block has content lines
        # @return [Boolean] True if has content
        def content?
          !lines.empty?
        end

        # Get the number of content lines
        # @return [Integer] Number of lines
        def line_count
          lines.size
        end
      end
    end
  end
end
