# frozen_string_literal: true

require 'review/ast/compiler'
require 'review/ast/list_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'

module ReVIEW
  module Renderer
    class ListStructureNormalizer
      def initialize(renderer)
        @renderer = renderer
      end

      def normalize(node)
        normalize_node(node)
      end

      private

      def normalize_node(node)
        return unless node.respond_to?(:children) && node.children

        assign_ordered_offsets(node)

        normalized_children = []
        children = node.children.dup
        idx = 0
        last_list_context = nil

        while idx < children.size
          child = children[idx]

          if beginchild_block?(child)
            nested_nodes, idx = extract_nested_child_sequence(children, idx)
            unless last_list_context
              raise ReVIEW::ApplicationError, "//beginchild is shown, but previous element isn't ul, ol, or dl"
            end

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

      def assign_ordered_offsets(node)
        return unless node.is_a?(ReVIEW::AST::ListNode)
        return unless node.list_type == :ol

        base = node.start_number || 1
        node.children&.each_with_index do |item, index|
          offset = base + index
          item.instance_variable_set(:@idgxml_ol_offset, offset)
        end
      end

      def extract_nested_child_sequence(children, begin_index)
        collected = []
        depth = 1
        idx = begin_index + 1

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
          end
          collected << current

          idx += 1
        end

        raise ReVIEW::ApplicationError, '//beginchild of dl,ol,ul misses //endchild'
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
            merged.last.children.concat(child.children)
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
            new_item = ReVIEW::AST::ListItemNode.new(level: 1)
            new_item.term_children = parse_inline_nodes(term_text)
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
          if child.respond_to?(:content)
            child.content
          else
            ''
          end
        end.join
      end

      def parse_inline_nodes(text)
        return [] if text.nil? || text.empty?

        temp_node = ReVIEW::AST::ParagraphNode.new(location: nil)
        ast_compiler.inline_processor.parse_inline_elements(text, temp_node)
        temp_node.children
      end

      def ast_compiler
        @renderer.ast_compiler
      end
    end
  end
end
