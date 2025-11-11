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
      # @param reference_resolution [Boolean] Whether to resolve references (default: true)
      # @return [DocumentNode] The compiled AST root
      def compile_to_ast(chapter, reference_resolution: true)
        @chapter = chapter

        # Create AST root
        @ast_root = AST::DocumentNode.new(
          location: SnapshotLocation.new(@chapter.basename, 1)
        )
        @current_ast_node = @ast_root

        # Parse Markdown with Markly
        # NOTE: tagfilter is removed to allow Re:VIEW inline notation @<xxx>{id}
        extensions = %i[strikethrough table autolink]

        # Preprocess: Extract footnote definitions and escape Re:VIEW inline notation
        markdown_content = @chapter.content
        ref_map = {}
        ref_counter = 0
        footnote_map = {}
        footnote_counter = 0
        footnote_ref_map = {}

        # Extract footnote definitions: [^id]: content
        # Footnotes can span multiple lines if indented
        lines = markdown_content.lines
        i = 0
        processed_lines = []

        while i < lines.length
          line = lines[i]

          # Check if this is a footnote definition
          if line =~ /^\[\^([^\]]+)\]:\s*(.*)$/
            footnote_id = ::Regexp.last_match(1)
            footnote_content = ::Regexp.last_match(2)

            # Collect continuation lines (indented lines)
            i += 1
            while i < lines.length && lines[i] =~ /^[ \t]+(.+)$/
              footnote_content += ' ' + ::Regexp.last_match(1).strip
              i += 1
            end

            # Store footnote definition
            placeholder = "@@FOOTNOTE_DEF_#{footnote_counter}@@"
            footnote_map[placeholder] = { id: footnote_id, content: footnote_content.strip }
            footnote_counter += 1

            # Replace with placeholder followed by blank line to ensure separate paragraph
            processed_lines << "#{placeholder}\n\n"
          else
            processed_lines << line
            i += 1
          end
        end

        markdown_content = processed_lines.join

        # Replace footnote references [^id] with placeholder
        markdown_content = markdown_content.gsub(/\[\^([^\]]+)\]/) do
          footnote_id = ::Regexp.last_match(1)
          placeholder = "@@FOOTNOTE_REF_#{ref_counter}@@"
          footnote_ref_map[placeholder] = footnote_id
          ref_counter += 1
          placeholder
        end

        # Replace Re:VIEW inline notation @<xxx>{id} with placeholder
        markdown_content = markdown_content.gsub(/@<([a-z]+)>\{([^}]+)\}/) do
          ref_type = ::Regexp.last_match(1)
          ref_id = ::Regexp.last_match(2)
          placeholder = "@@REVIEW_REF_#{ref_counter}@@"
          ref_map[placeholder] = { type: ref_type, id: ref_id }
          ref_counter += 1
          placeholder
        end

        # Parse the Markdown content
        markly_doc = Markly.parse(
          markdown_content,
          extensions: extensions
        )

        # Convert Markly AST to Re:VIEW AST
        @adapter.convert(markly_doc, @ast_root, @chapter,
                         ref_map: ref_map,
                         footnote_map: footnote_map,
                         footnote_ref_map: footnote_ref_map)

        if reference_resolution
          resolve_references
        end

        @ast_root
      end

      # Resolve references using ReferenceResolver
      # This also builds indexes which sets chapter title
      def resolve_references
        # Skip reference resolution in test environments or when chapter lacks book context
        return unless @chapter.book

        require_relative('reference_resolver')
        resolver = ReferenceResolver.new(@chapter)
        resolver.resolve_references(@ast_root)
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
