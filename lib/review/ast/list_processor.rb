# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/list_parser'
require 'review/ast/list_processor/nested_list_assembler'

module ReVIEW
  module AST
    # ListProcessor - Main coordinator for list processing
    #
    # This class orchestrates the full list processing pipeline by coordinating
    # between ListParser (for parsing) and NestedListAssembler (for AST construction).
    # It provides clean, testable methods that replace the monolithic list processing
    # methods in ASTCompiler.
    #
    # Responsibilities:
    # - Coordinate the full list processing pipeline
    # - Provide clean interfaces for different list types
    # - Handle rendering through AST renderer
    # - Manage dependencies between parser, builder, and renderer
    class ListProcessor
      def initialize(ast_compiler)
        @ast_compiler = ast_compiler
        @parser = ListParser.new(ast_compiler)
        @nested_list_assembler = NestedListAssembler.new(ast_compiler, ast_compiler.inline_processor)
      end

      # Process unordered list from file input
      # @param f [LineInput] Input file stream
      def process_unordered_list(f)
        items = @parser.parse_unordered_list(f)
        return if items.empty?

        list_node = @nested_list_assembler.build_unordered_list(items)
        add_to_ast(list_node)
      end

      # Process ordered list from file input
      # @param f [LineInput] Input file stream
      def process_ordered_list(f)
        items = @parser.parse_ordered_list(f)
        return if items.empty?

        list_node = @nested_list_assembler.build_ordered_list(items)
        add_to_ast(list_node)
      end

      # Process definition list from file input
      # @param f [LineInput] Input file stream
      def process_definition_list(f)
        items = @parser.parse_definition_list(f)
        return if items.empty?

        list_node = @nested_list_assembler.build_definition_list(items)
        add_to_ast(list_node)
      end

      # Process any list type (for generic handling)
      # @param f [LineInput] Input file stream
      # @param list_type [Symbol] Type of list (:ul, :ol, :dl)
      def process_list(f, list_type)
        case list_type
        when :ul
          process_unordered_list(f)
        when :ol
          process_ordered_list(f)
        when :dl
          process_definition_list(f)
        else
          location_info = @ast_compiler.location.format_for_error
          raise CompileError, "Unknown list type: #{list_type}#{location_info}"
        end
      end

      # Build list from pre-parsed items (for testing or special cases)
      # @param items [Array<ListParser::ListItemData>] Pre-parsed items
      # @param list_type [Symbol] Type of list
      # @return [ListNode] Built list node
      def build_list_from_items(items, list_type)
        @nested_list_assembler.build_nested_structure(items, list_type)
      end

      # Parse list items without building AST (for testing)
      # @param f [LineInput] Input file stream
      # @param list_type [Symbol] Type of list
      # @return [Array<ListParser::ListItemData>] Parsed items
      def parse_list_items(f, list_type)
        case list_type
        when :ul
          @parser.parse_unordered_list(f)
        when :ol
          @parser.parse_ordered_list(f)
        when :dl
          @parser.parse_definition_list(f)
        else
          location_info = @ast_compiler.location.format_for_error
          raise CompileError, "Unknown list type: #{list_type}#{location_info}"
        end
      end

      # Get parser for testing or direct access
      # @return [ListParser] The list parser instance
      attr_reader :parser

      # Get builder for testing or direct access
      # @return [NestedListAssembler] The list builder instance
      attr_reader :nested_list_assembler

      private

      # Add list node to AST
      # @param list_node [ListNode] List node to add
      def add_to_ast(list_node)
        @ast_compiler.add_child_to_current_node(list_node)
      end
    end
  end
end
