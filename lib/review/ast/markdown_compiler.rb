# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative 'compiler'
require_relative 'markdown_adapter'
require 'markly'

module ReVIEW
  module AST
    # MarkdownCompiler - Compiler for GitHub Flavored Markdown documents
    #
    # This class compiles Markdown documents to Re:VIEW AST using Markly
    # for parsing and MarkdownAdapter for AST conversion.
    class MarkdownCompiler < Compiler
      def initialize
        super
        @adapter = MarkdownAdapter.new(self)
      end

      # Compile Markdown content to AST
      #
      # @param chapter [ReVIEW::Book::Chapter] Chapter context
      # @return [DocumentNode] The compiled AST root
      def compile_to_ast(chapter)
        @chapter = chapter

        # Create AST root
        @ast_root = AST::DocumentNode.new(
          location: SnapshotLocation.new(@chapter.basename, 1),
          chapter: @chapter
        )
        @current_ast_node = @ast_root

        # Parse Markdown with Markly
        extensions = %i[strikethrough table autolink tagfilter]

        # Parse the Markdown content
        markdown_content = @chapter.content
        markly_doc = Markly.parse(
          markdown_content,
          extensions: extensions
        )

        # Convert Markly AST to Re:VIEW AST
        @adapter.convert(markly_doc, @ast_root, @chapter)

        @ast_root
      end

      # Helper method to provide location information
      def location
        @current_location || SnapshotLocation.new(@chapter.basename, 1)
      end

      # Add child to current node
      def add_child_to_current_node(node)
        @current_ast_node.add_child(node)
      end

      # Push a new context node
      def push_context(node)
        @current_ast_node = node
      end

      # Pop context node
      def pop_context
        @current_ast_node = @current_ast_node.parent || @ast_root
      end
    end
  end
end
