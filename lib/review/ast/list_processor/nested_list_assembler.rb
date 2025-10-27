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
    class ListProcessor
      # NestedListAssembler - Build nested list AST structures
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
      class NestedListAssembler
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
            raise ReVIEW::CompileError, "Unknown list type: #{list_type}"
          end
        end

        # Build unordered list with proper nesting
        # @param items [Array<ListParser::ListItemData>] Parsed unordered list items
        # @return [ReVIEW::AST::ListNode] Root unordered list node
        def build_unordered_list(items)
          root_list = create_list_node(:ul)
          build_proper_nested_structure(items, root_list, :ul)
          root_list
        end

        # Build ordered list with proper nesting
        # @param items [Array<ListParser::ListItemData>] Parsed ordered list items
        # @return [ReVIEW::AST::ListNode] Root ordered list node
        def build_ordered_list(items)
          root_list = create_list_node(:ol)

          # Set start_number based on the first item's number if available
          if items.first && items.first.metadata[:number]
            root_list.start_number = items.first.metadata[:number]
          end

          build_proper_nested_structure(items, root_list, :ol)
          root_list
        end

        # Build definition list with proper structure
        # @param items [Array<ListParser::ListItemData>] Parsed definition list items
        # @return [ReVIEW::AST::ListNode] Root definition list node
        def build_definition_list(items)
          root_list = create_list_node(:dl)

          items.each do |item_data|
            # For definition lists, process the term inline elements first
            term_children = process_definition_term_content(item_data.content)

            # Create list item for term/definition pair with term_children
            item_node = create_list_item_node(item_data, term_children: term_children)

            # Add definition content (additional children) - only definition, not term
            item_data.continuation_lines.each do |definition_line|
              add_definition_content(item_node, definition_line)
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
          previous_level = 0 # Track previous level for validation

          items.each do |item_data|
            level = item_data.level || 1

            # Validate nesting level transition
            if level > previous_level
              level_diff = level - previous_level
              if level_diff > 1
                # Nesting level jumped too much (e.g., ** before * or *** after *)
                # Log error (same as Builder) and continue processing
                if @location_provider.respond_to?(:error)
                  @location_provider.error('too many *.')
                elsif @location_provider.respond_to?(:logger)
                  @location_provider.logger.error('too many *.')
                end
                # Adjust level to prevent invalid jump (same as Builder)
                level = previous_level + 1
              end
            end
            previous_level = level

            # Create the list item with adjusted level if needed
            adjusted_item_data = if level == item_data.level
                                   item_data
                                 else
                                   # Create new item data with adjusted level
                                   ReVIEW::AST::ListParser::ListItemData.new(
                                     type: item_data.type,
                                     level: level,
                                     content: item_data.content,
                                     continuation_lines: item_data.continuation_lines,
                                     metadata: item_data.metadata
                                   )
                                 end

            item_node = create_list_item_node(adjusted_item_data)
            add_all_content_to_item(item_node, adjusted_item_data)

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
                  child.is_a?(ReVIEW::AST::ListNode) && child.list_type == list_type
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
        # @param root_list [ReVIEW::AST::ListNode] Root list node
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
        # @param target_list [ReVIEW::AST::ListNode] Parent list
        # @param list_type [Symbol] Type of nested list to create
        # @return [ReVIEW::AST::ListNode, nil] Nested list or nil if no nesting possible
        def find_or_create_nested_list(target_list, list_type)
          # The nested list should be a child of the last item in the current list
          return nil unless target_list.children.any? && target_list.children.last.is_a?(ReVIEW::AST::ListItemNode)

          last_item = target_list.children.last

          # Check if the last item already has a nested list of the same type
          nested_list = last_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) && child.list_type == list_type }

          unless nested_list
            # Create new nested list
            nested_list = create_list_node(list_type)
            last_item.add_child(nested_list)
          end

          nested_list
        end

        # Add all content from item data to list item node
        # @param item_node [ReVIEW::AST::ListItemNode] Target item node
        # @param item_data [ListParser::ListItemData] Source item data
        def add_all_content_to_item(item_node, item_data)
          # Add main content
          add_content_to_item(item_node, item_data.content)

          # Add continuation lines
          item_data.continuation_lines.each do |line|
            add_content_to_item(item_node, line)
          end
        end

        # Add content to list item using inline processor
        # @param item_node [ReVIEW::AST::ListItemNode] Target item node
        # @param content [String] Content to add
        def add_content_to_item(item_node, content)
          @inline_processor.parse_inline_elements(content, item_node)
        end

        # Add definition content with special handling for definition lists
        # @param item_node [ReVIEW::AST::ListItemNode] Target item node
        # @param definition_content [String] Definition content
        def add_definition_content(item_node, definition_content)
          if definition_content.include?('@<')
            # Create a paragraph node to hold the definition with inline elements
            definition_paragraph = ReVIEW::AST::ParagraphNode.new(location: current_location)
            @inline_processor.parse_inline_elements(definition_content, definition_paragraph)
            item_node.add_child(definition_paragraph)
          else
            # Create a simple text node for the definition
            definition_node = ReVIEW::AST::TextNode.new(location: current_location, content: definition_content)
            item_node.add_child(definition_node)
          end
        end

        # Process definition list term content with inline elements
        # @param term_content [String] Term content to process
        # @return [Array<Node>] Processed term children nodes
        def process_definition_term_content(term_content)
          # Create a temporary container to collect processed term elements
          temp_container = ReVIEW::AST::ParagraphNode.new(location: current_location)
          @inline_processor.parse_inline_elements(term_content, temp_container)

          # Return the processed elements
          temp_container.children
        end

        # Create a new ListNode
        # @param list_type [Symbol] Type of list (:ul, :ol, :dl, etc.)
        # @return [ReVIEW::AST::ListNode] New list node
        def create_list_node(list_type)
          ReVIEW::AST::ListNode.new(location: current_location, list_type: list_type)
        end

        # Create a new ListItemNode from parsed data
        # @param item_data [ListParser::ListItemData] Parsed item data
        # @param term_children [Array<Node>] Optional term children for definition lists
        # @return [ReVIEW::AST::ListItemNode] New list item node
        def create_list_item_node(item_data, term_children: [])
          node_attributes = {
            location: current_location,
            level: item_data.level,
            term_children: term_children
          }

          # Add type-specific attributes
          case item_data.type
          when :ol
            node_attributes[:number] = item_data.metadata[:number]
          when :dl
            # For definition lists, term content is processed separately via term_children
            # Definition content is added as children nodes
          end

          ReVIEW::AST::ListItemNode.new(**node_attributes)
        end

        # Create empty list node
        # @param list_type [Symbol] Type of list
        # @return [ReVIEW::AST::ListNode] Empty list node
        def create_empty_list(list_type)
          ReVIEW::AST::ListNode.new(location: current_location, list_type: list_type)
        end

        # Get current location for node creation
        # @return [Location, nil] Current location
        def current_location
          @location_provider&.location
        end
      end
    end
  end
end
