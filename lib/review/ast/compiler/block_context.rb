# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    class Compiler
      # BlockContext - Scoped context for block processing
      #
      # This class provides consistent location information and processing environment
      # for specific blocks (//list, //image, //table, etc.).
      #
      # Main features:
      # - Maintain and propagate block start location
      # - Node creation within context
      # - Accurate location information for inline processing
      # - Support for nested block processing
      class BlockContext
        attr_reader :start_location, :compiler, :block_data

        def initialize(block_data:, compiler:)
          @block_data = block_data
          @start_location = block_data.location
          @compiler = compiler
        end

        # Create AST node within this context
        # Location information is automatically set to block start location
        #
        # @param node_class [Class] Node class to create
        # @param attrs [Hash] Node attributes
        # @return [AST::Node] Created node
        def create_node(node_class, **attrs)
          # Use block start location if location is not explicitly specified
          attrs[:location] ||= @start_location
          node_class.new(**attrs)
        end

        # Process inline elements within this context
        # Temporarily override compiler's location information to block start location
        #
        # @param text [String] Text to process
        # @param parent_node [AST::Node] Parent node to add inline elements to
        def process_inline_elements(text, parent_node)
          # Use bang method to safely override location information temporarily
          @compiler.with_temporary_location!(@start_location) do
            @compiler.inline_processor.parse_inline_elements(text, parent_node)
          end
        end

        # Process caption within this context
        # Generate caption using block start location
        #
        # @param args [Array<String>] Arguments array
        # @param caption_index [Integer] Caption index
        # @return [CaptionNode, nil] Processed caption node or nil
        def process_caption(args, caption_index)
          return nil unless args && caption_index && caption_index >= 0 && args.size > caption_index

          caption_text = args[caption_index]
          return nil if caption_text.nil?

          @compiler.build_caption_node(caption_text, caption_location: @start_location)
        end

        # Process nested blocks
        # Recursively process each nested block and add to parent node
        #
        # @param parent_node [AST::Node] Parent node to add nested blocks to
        def process_nested_blocks(parent_node)
          return unless @block_data.nested_blocks?

          # Use bang method to safely override AST node context temporarily
          @compiler.with_temporary_ast_node!(parent_node) do
            # Process nested blocks recursively
            @block_data.nested_blocks.each do |nested_block|
              @compiler.block_processor.process_block_command(nested_block)
            end
          end
        end

        # Integrated processing of structured content and nested blocks
        # Properly handle both text lines and nested blocks
        #
        # @param parent_node [AST::Node] Parent node to add content to
        def process_structured_content_with_blocks(parent_node)
          # Process regular lines
          if @block_data.content?
            @compiler.process_structured_content(parent_node, @block_data.lines)
          end

          # Process nested blocks
          process_nested_blocks(parent_node)
        end

        # Safely get block data arguments
        #
        # @param index [Integer] Argument index
        # @return [String, nil] Argument value or nil
        def arg(index)
          @block_data.arg(index)
        end

        # Check if block has content
        #
        # @return [Boolean] Whether content exists
        def content?
          @block_data.content?
        end

        # Check if block has nested blocks
        #
        # @return [Boolean] Whether nested blocks exist
        def nested_blocks?
          @block_data.nested_blocks?
        end

        # Get block line count
        #
        # @return [Integer] Line count
        def line_count
          @block_data.line_count
        end

        # Get block content lines
        #
        # @return [Array<String>] Array of content lines
        def lines
          @block_data.lines
        end

        # Get block name
        #
        # @return [Symbol] Block name
        def name
          @block_data.name
        end

        # Get block arguments
        #
        # @return [Array<String>] Array of arguments
        def args
          @block_data.args
        end

        # Debug string representation
        #
        # @return [String] Debug string
        def inspect
          "#<BlockContext name=#{name} location=#{@start_location&.lineno || 'nil'} lines=#{line_count}>"
        end
      end
    end
  end
end
