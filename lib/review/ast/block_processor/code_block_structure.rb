# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class BlockProcessor
      # Data structure representing code block structure (intermediate representation)
      CodeBlockStructure = Data.define(:id, :caption_node, :lang, :line_numbers, :code_type, :lines, :original_text) do
        # @param context [BlockContext] Block context
        # @param config [Hash] Code block configuration
        # @return [CodeBlockStructure] Parsed code block structure
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

        def numbered?
          line_numbers
        end

        def content?
          !lines.empty?
        end

        def caption_text
          caption_node&.to_text || ''
        end
      end
    end
  end
end
