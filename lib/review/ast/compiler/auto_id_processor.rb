# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'

module ReVIEW
  module AST
    # AutoIdProcessor - Post-process to generate auto_id for nodes without explicit labels
    #
    # This processor assigns automatic IDs to:
    # - HeadlineNode with nonum/notoc/nodisp tags (when label is not provided)
    # - ColumnNode (always, used for anchor generation)
    #
    # Auto IDs are generated with sequential counters to ensure uniqueness.
    class AutoIdProcessor
      def self.process(ast_root, chapter:)
        new(ast_root, chapter).process
      end

      def initialize(ast_root, chapter)
        @ast_root = ast_root
        @chapter = chapter
        @nonum_counter = 0
        @column_counter = 0
      end

      def process
        visit(@ast_root)
        @ast_root
      end

      # Visit HeadlineNode - assign auto_id if needed
      def visit_headline(node)
        # Only assign auto_id to special headlines without explicit label
        if needs_auto_id?(node) && !node.label
          @nonum_counter += 1
          chapter_name = @chapter&.name || 'test'
          node.auto_id = "#{chapter_name}_nonum#{@nonum_counter}"
        end

        visit_children(node)
        node
      end

      # Visit ColumnNode - always assign auto_id and column_number
      def visit_column(node)
        @column_counter += 1
        node.auto_id = "column-#{@column_counter}"
        node.column_number = @column_counter

        visit_children(node)
        node
      end

      def visit_document(node)
        visit_children(node)
        node
      end

      def visit(node)
        case node
        when HeadlineNode
          visit_headline(node)
        when ColumnNode
          visit_column(node)
        when DocumentNode
          visit_document(node)
        else
          # For other nodes, just visit children
          visit_children(node) if node.respond_to?(:children)
          node
        end
      end

      private

      def needs_auto_id?(node)
        node.is_a?(HeadlineNode) && (node.nonum? || node.notoc? || node.nodisp?)
      end

      def visit_children(node)
        return unless node.respond_to?(:children)

        node.children.each { |child| visit(child) }
      end
    end
  end
end
