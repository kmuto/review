# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/list_node'
require 'review/ast/text_node'
require 'review/ast/paragraph_node'

module ReVIEW
  module AST
    # NestedListBuilder - Build nested list AST structures
    #
    # This class constructs properly nested AST node structures from
    # parsed list item data. It handles the complex logic of building
    # nested parent-child relationships between list nodes and items.
    #
    # Responsibilities:
    # - Build nested ListNode and ListItemNode structures
    # - Handle different list types (ul, ol, dl) with type-specific logic
    # - Manage nesting levels and parent-child relationships
    # - Create proper AST hierarchy for complex nested lists
    #
    class NestedListBuilder
      def initialize(location_provider, inline_processor)
        @location_provider = location_provider
        @inline_processor = inline_processor
      end

      # Build nested list structure from flat list items
      # @param items [Array<ListParser::ListItemData>] Parsed list items
      # @param list_type [Symbol] List type (:ul, :ol, :dl)
      # @return [ListNode] Root list node with nested structure
      def build_nested_structure(items, list_type)
        return create_empty_list(list_type) if items.empty?

        case list_type
        when :ul
          build_unordered_list(items)
        when :ol
          build_ordered_list(items)
        when :dl
          build_definition_list(items)
        else
          build_generic_list(items, list_type)
        end
      end

      # Build unordered list with proper nesting
      # @param items [Array<ListParser::ListItemData>] Parsed unordered list items
      # @return [ListNode] Root unordered list node
      def build_unordered_list(items)
        root_list = create_list_node(:ul)
        build_proper_nested_structure(items, root_list, :ul)
        root_list
      end

      # Build ordered list with proper nesting
      # @param items [Array<ListParser::ListItemData>] Parsed ordered list items
      # @return [ListNode] Root ordered list node
      def build_ordered_list(items)
        root_list = create_list_node(:ol)

        build_proper_nested_structure(items, root_list, :ol)
        root_list
      end

      # Build definition list with proper structure
      # @param items [Array<ListParser::ListItemData>] Parsed definition list items
      # @return [ListNode] Root definition list node
      def build_definition_list(items)
        root_list = create_list_node(:dl)

        items.each do |item_data|
          # Create list item for term/definition pair
          item_node = create_list_item_node(item_data)

          # Add term content (first child)
          add_content_to_item(item_node, item_data.content)

          # Add definition content (additional children)
          item_data.continuation_lines.each do |definition_line|
            add_definition_content(item_node, definition_line)
          end

          root_list.add_child(item_node)
        end

        root_list
      end

      # Build generic list for unknown types
      # @param items [Array<ListParser::ListItemData>] Parsed list items
      # @param list_type [Symbol] List type
      # @return [ListNode] Root list node
      def build_generic_list(items, list_type)
        root_list = create_list_node(list_type)

        items.each do |item_data|
          item_node = create_list_item_node(item_data)
          add_content_to_item(item_node, item_data.content)
          item_data.continuation_lines.each do |line|
            add_content_to_item(item_node, line)
          end
          root_list.add_child(item_node)
        end

        root_list
      end

      private

      # Build proper nested structure as Re:VIEW expects
      def build_proper_nested_structure(items, root_list, list_type)
        return if items.empty?

        current_lists = { 1 => root_list } # Track list at each level

        items.each do |item_data|
          level = item_data.level || 1

          # Create the list item
          item_node = create_list_item_node(item_data)
          add_all_content_to_item(item_node, item_data)

          # Ensure we have a list at the appropriate level
          if level == 1
            # Level 1 items go directly to root
            root_list.add_child(item_node)
            current_lists[1] = root_list
          else
            # For level > 1, ensure parent structure exists
            parent_level = level - 1
            parent_list = current_lists[parent_level]

            if parent_list&.children&.any?
              # Get the last item at parent level to attach nested list to
              last_parent_item = parent_list.children.last

              # Check if this item already has a nested list
              nested_list = last_parent_item.children.find do |child|
                child.is_a?(ListNode) && child.list_type == list_type
              end

              unless nested_list
                # Create new nested list
                nested_list = create_list_node(list_type)
                last_parent_item.add_child(nested_list)
              end

              # Add item to nested list
              nested_list.add_child(item_node)
              current_lists[level] = nested_list
            end
          end
        end
      end

      # Build nested items using stack-based approach for proper nesting
      # @param items [Array<ListParser::ListItemData>] Parsed list items
      # @param root_list [ListNode] Root list node
      # @param list_type [Symbol] List type for nested sublists
      def build_nested_items_with_stack(items, root_list, list_type)
        return if items.empty?

        # Initialize stack with root list at level 0
        stack = [{ list: root_list, level: 0 }]

        items.each do |item_data|
          current_level = item_data.level || 1

          # Pop from stack until we find the appropriate parent level
          while stack.size > 1 && stack.last[:level] >= current_level
            stack.pop
          end

          current_context = stack.last
          target_list = current_context[:list]

          # Create the list item node
          item_node = create_list_item_node(item_data)
          add_all_content_to_item(item_node, item_data)

          if current_context[:level] < current_level
            # Need to create a deeper nested structure
            nested_list = find_or_create_nested_list(target_list, list_type)
            if nested_list
              # Add item to nested list and update stack
              nested_list.add_child(item_node)
              stack.push({ list: nested_list, level: current_level })
            else
              # No previous item to nest under, add to current level
              target_list.add_child(item_node)
            end
          else
            # Same level or going back up, add to current list
            target_list.add_child(item_node)
          end
        end
      end

      # Find existing or create new nested list
      # @param target_list [ListNode] Parent list
      # @param list_type [Symbol] Type of nested list to create
      # @return [ListNode, nil] Nested list or nil if no nesting possible
      def find_or_create_nested_list(target_list, list_type)
        # The nested list should be a child of the last item in the current list
        return nil unless target_list.children.any? && target_list.children.last.is_a?(ListItemNode)

        last_item = target_list.children.last

        # Check if the last item already has a nested list of the same type
        nested_list = last_item.children.find { |child| child.is_a?(ListNode) && child.list_type == list_type }

        unless nested_list
          # Create new nested list
          nested_list = create_list_node(list_type)
          last_item.add_child(nested_list)
        end

        nested_list
      end

      # Add all content from item data to list item node
      # @param item_node [ListItemNode] Target item node
      # @param item_data [ListParser::ListItemData] Source item data
      def add_all_content_to_item(item_node, item_data)
        # Add main content
        add_content_to_item(item_node, item_data.content)

        # Add continuation lines
        item_data.continuation_lines.each do |line|
          add_content_to_item(item_node, line)
        end
      end

      # Add content to list item using inline processor if available
      # @param item_node [ListItemNode] Target item node
      # @param content [String] Content to add
      def add_content_to_item(item_node, content)
        if @inline_processor
          @inline_processor.parse_inline_elements(content, item_node)
        else
          # Fallback: create simple text node
          text_node = AST::TextNode.new(location: current_location, content: content)
          item_node.add_child(text_node)
        end
      end

      # Add definition content with special handling for definition lists
      # @param item_node [ListItemNode] Target item node
      # @param definition_content [String] Definition content
      def add_definition_content(item_node, definition_content)
        if definition_content.include?('@<')
          # Create a paragraph node to hold the definition with inline elements
          definition_paragraph = AST::ParagraphNode.new(location: current_location)
          if @inline_processor
            @inline_processor.parse_inline_elements(definition_content, definition_paragraph)
          else
            text_node = AST::TextNode.new(location: current_location, content: definition_content)
            definition_paragraph.add_child(text_node)
          end
          item_node.add_child(definition_paragraph)
        else
          # Create a simple text node for the definition
          definition_node = AST::TextNode.new(location: current_location, content: definition_content)
          item_node.add_child(definition_node)
        end
      end

      # Create a new ListNode
      # @param list_type [Symbol] Type of list (:ul, :ol, :dl, etc.)
      # @return [ListNode] New list node
      def create_list_node(list_type)
        ListNode.new(location: current_location, list_type: list_type)
      end

      # Create a new ListItemNode from parsed data
      # @param item_data [ListParser::ListItemData] Parsed item data
      # @return [ListItemNode] New list item node
      def create_list_item_node(item_data)
        node_attributes = {
          location: current_location,
          level: item_data.level
        }

        # Add type-specific attributes
        case item_data.type
        when :ol
          node_attributes[:content] = item_data.metadata[:number_string]
          node_attributes[:number] = item_data.metadata[:number]
        when :dl
          node_attributes[:content] = item_data.content
        end

        ListItemNode.new(**node_attributes)
      end

      # Create empty list node
      # @param list_type [Symbol] Type of list
      # @return [ListNode] Empty list node
      def create_empty_list(list_type)
        ListNode.new(location: current_location, list_type: list_type)
      end

      # Get current location for node creation
      # @return [Location, nil] Current location
      def current_location
        @location_provider&.location
      end
    end
  end
end
