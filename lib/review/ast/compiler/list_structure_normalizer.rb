# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/block_node'
require 'review/ast/list_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'
require 'review/ast/inline_processor'
require_relative 'post_processor'

module ReVIEW
  module AST
    class Compiler
      # ListStructureNormalizer - Processes //beginchild and //endchild commands in AST
      #
      # This processor transforms the flat structure created by //beginchild and //endchild
      # into proper nested list structures. It also handles definition list paragraph splitting.
      #
      # Processing:
      # 1. Finds //beginchild and //endchild block pairs
      # 2. Moves nodes between them into the last list item
      # 3. Removes the //beginchild and //endchild block nodes
      # 4. Merges consecutive lists of the same type
      # 5. Splits definition list paragraphs into separate terms
      #
      # Execution Order (in AST::Compiler):
      # 1. OlnumProcessor - Sets start_number on ordered lists
      # 2. ListStructureNormalizer - Normalizes list structure (this class)
      # 3. ListItemNumberingProcessor - Assigns item_number to each list item
      #
      # This processor only handles structural transformations and does not deal with
      # item numbering. Item numbers are assigned later by ListItemNumberingProcessor
      # based on the normalized structure.
      #
      # Usage:
      #   ListStructureNormalizer.process(ast_root)
      class ListStructureNormalizer < PostProcessor
        private

        def process_node(node)
          normalize_node(node)
        end

        def normalize_node(node)
          return if node.children.empty?

          normalized_children = []
          children = node.children.dup
          idx = 0
          last_list_context = nil

          while idx < children.size
            child = children[idx]

            if beginchild_block?(child)
              unless last_list_context
                raise ReVIEW::ApplicationError, "//beginchild is shown, but previous element isn't ul, ol, or dl"
              end

              nested_nodes, idx = extract_nested_child_sequence(children, idx, last_list_context)
              nested_nodes.each { |nested| normalize_node(nested) }
              nested_nodes.each { |nested| last_list_context[:item].add_child(nested) }
              normalize_node(last_list_context[:item])
              last_list_context[:item] = last_list_context[:list_node].children.last
              next
            end

            if endchild_block?(child)
              raise ReVIEW::ApplicationError, "//endchild is shown, but any opened //beginchild doesn't exist"
            end

            if paragraph_node?(child) &&
               last_list_context &&
               last_list_context[:list_type] == :dl &&
               definition_paragraph?(child)
              transfer_definition_paragraph(last_list_context, child)
              last_list_context[:item] = last_list_context[:list_node].children.last
              idx += 1
              next
            end

            normalize_node(child)
            normalized_children << child
            last_list_context = last_list_context_for(child)
            idx += 1
          end

          node.children.replace(merge_consecutive_lists(normalized_children))
        end

        def extract_nested_child_sequence(children, begin_index, initial_list_context = nil)
          collected = []
          depth = 1
          idx = begin_index + 1
          # Track list types for better error messages
          list_type_stack = initial_list_context ? [initial_list_context[:list_type]] : []

          while idx < children.size
            current = children[idx]

            if beginchild_block?(current)
              depth += 1
            elsif endchild_block?(current)
              depth -= 1
              if depth == 0
                idx += 1
                return [collected, idx]
              end
              # Pop from stack when we close a nested beginchild
              list_type_stack.pop unless list_type_stack.empty?
            end

            # Track list types as we encounter them
            if current.is_a?(ReVIEW::AST::ListNode) && current.children.any?
              list_type_stack.push(current.list_type)
            end

            collected << current
            idx += 1
          end

          # Generate error message with tracked list types
          if list_type_stack.empty?
            raise ReVIEW::ApplicationError, '//beginchild of dl,ol,ul misses //endchild'
          else
            # Reverse to show the order like Builder does (most recent first)
            types = list_type_stack.reverse.join(',')
            raise ReVIEW::ApplicationError, "//beginchild of #{types} misses //endchild"
          end
        end

        def beginchild_block?(node)
          node.is_a?(ReVIEW::AST::BlockNode) && node.block_type == :beginchild
        end

        def endchild_block?(node)
          node.is_a?(ReVIEW::AST::BlockNode) && node.block_type == :endchild
        end

        def paragraph_node?(node)
          node.is_a?(ReVIEW::AST::ParagraphNode)
        end

        def definition_paragraph?(paragraph)
          text = paragraph_text(paragraph)
          text.lines.any? { |line| line =~ /\A\s*[:\t]/ }
        end

        def last_list_context_for(node)
          return nil unless node.is_a?(ReVIEW::AST::ListNode) && node.children.any?

          {
            item: node.children.last,
            list_node: node,
            list_type: node.list_type
          }
        end

        def merge_consecutive_lists(children)
          merged = []

          children.each do |child|
            if child.is_a?(ReVIEW::AST::ListNode) &&
               merged.last.is_a?(ReVIEW::AST::ListNode) &&
               merged.last.list_type == child.list_type
              # Merge the children from the second list into the first
              # Note: item_number will be assigned later by ListItemNumberingProcessor
              child.children.each do |item|
                merged.last.add_child(item)
              end
            else
              merged << child
            end
          end

          merged
        end

        def transfer_definition_paragraph(context, paragraph)
          list_node = context[:list_node]
          current_item = context[:item]
          text = paragraph_text(paragraph)

          text.each_line do |line|
            stripped = line.strip
            next if stripped.empty?

            if line.lstrip.start_with?(':')
              term_text = line.sub(/\A\s*:\s*/, '').strip
              term_children = parse_inline_nodes(term_text)
              new_item = ReVIEW::AST::ListItemNode.new(level: 1, term_children: term_children)
              list_node.add_child(new_item)
              current_item = new_item
            else
              inline_nodes = parse_inline_nodes(stripped)
              inline_nodes = [ReVIEW::AST::TextNode.new(content: stripped)] if inline_nodes.empty?
              inline_nodes.each { |node| current_item.add_child(node) }
            end
          end

          context[:item] = list_node.children.last
        end

        def paragraph_text(paragraph)
          paragraph.children.map do |child|
            if child.leaf_node?
              child.content
            else
              ''
            end
          end.join
        end

        def parse_inline_nodes(text)
          return [] if text.nil? || text.empty?

          temp_node = ReVIEW::AST::ParagraphNode.new(location: nil)
          @compiler.inline_processor.parse_inline_elements(text, temp_node)
          temp_node.children
        end
      end
    end
  end
end
