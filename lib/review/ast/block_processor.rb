# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/ast/block_data'
require 'review/lineinput'
require 'stringio'

module ReVIEW
  module AST
    # BlockProcessor - Block command processing and AST building
    #
    # This class handles the conversion of Re:VIEW block commands to AST nodes,
    # including code blocks, images, tables, lists, quotes, and minicolumns.
    #
    # Responsibilities:
    # - Process block commands (//list, //image, //table, etc.)
    # - Build appropriate AST nodes for block elements
    # - Handle block-specific parsing (table structure, list items, etc.)
    # - Coordinate with inline processor for content within blocks
    class BlockProcessor
      # Configuration object for BlockProcessor
      # This provides a clean API for configuring custom blocks and code blocks
      class Configuration
        def initialize(processor)
          @processor = processor
        end

        # Register a custom block handler
        # @param command_name [Symbol] The block command name
        # @param handler_method [Symbol] The handler method name
        # @see BlockProcessor#register_block_handler
        # @example
        #   config.register_block_handler(:custom_box, :build_custom_box_ast)
        def register_block_handler(command_name, handler_method)
          @processor.register_block_handler(command_name, handler_method)
        end

        # Register a custom code block type
        # @param command_name [Symbol] The code block command name
        # @param config [Hash] Configuration options
        # @see BlockProcessor#register_code_block_handler
        # @example
        #   config.register_code_block(:python)
        #   config.register_code_block(:pythonnum, line_numbers: true)
        def register_code_block(command_name, config = {})
          @processor.register_code_block_handler(command_name, config)
        end
      end

      # Class-level storage for configuration blocks
      @@configuration_blocks = [] # rubocop:disable Style/ClassVars

      class << self
        # Configure BlockProcessor with custom blocks and code blocks
        # This method allows users to register custom handlers in a clean,
        # declarative way without needing to override initialize.
        #
        # @yield [config] Configuration block
        # @yieldparam config [Configuration] Configuration object
        #
        # @example Register custom code blocks
        #   ReVIEW::AST::BlockProcessor.configure do |config|
        #     config.register_code_block(:python)
        #     config.register_code_block(:pythonnum, line_numbers: true)
        #   end
        #
        # @example Register custom block handlers
        #   ReVIEW::AST::BlockProcessor.configure do |config|
        #     config.register_block_handler(:custom_box, :build_custom_box_ast)
        #   end
        #
        # @example Register both types
        #   ReVIEW::AST::BlockProcessor.configure do |config|
        #     config.register_code_block(:python)
        #     config.register_block_handler(:custom_box, :build_custom_box_ast)
        #   end
        def configure(&block)
          @@configuration_blocks << block if block
        end

        # Get all registered configuration blocks (for testing)
        # @return [Array<Proc>] Array of configuration blocks
        def configuration_blocks
          @@configuration_blocks.dup
        end

        # Clear all configuration blocks (for testing)
        def clear_configuration
          @@configuration_blocks.clear
        end
      end

      def initialize(ast_compiler)
        @ast_compiler = ast_compiler
        # Copy the static tables to allow runtime modifications
        @dynamic_command_table = BLOCK_COMMAND_TABLE.dup
        @dynamic_code_block_configs = CODE_BLOCK_CONFIGS.dup

        # Apply configuration blocks
        apply_configuration
      end

      private

      # Apply all registered configuration blocks
      def apply_configuration
        config = Configuration.new(self)
        self.class.class_variable_get(:@@configuration_blocks).each do |block|
          block.call(config)
        end
      end

      public

      # Register a new block command handler
      # @param command_name [Symbol] The block command name (e.g., :custom_block)
      # @param handler_method [Symbol] The method name to handle this command
      # @example
      #   register_block_handler(:custom_block, :build_custom_block_ast)
      def register_block_handler(command_name, handler_method)
        @dynamic_command_table[command_name] = handler_method
      end

      # @return [Array<Symbol>] List of all registered command names
      def registered_commands
        @dynamic_command_table.keys
      end

      # Register a custom code block type with its configuration
      #
      # @param command_name [Symbol] The code block command name (e.g., :python, :javascript)
      # @param config [Hash] Configuration options
      # @option config [Integer] :id_index Index of ID argument (optional, for //list-style blocks)
      # @option config [Integer] :caption_index Index of caption argument (default: 0)
      # @option config [Integer] :lang_index Index of language argument (default: 1)
      # @option config [String] :default_lang Default language if lang_index not provided (default: command_name)
      # @option config [Boolean] :line_numbers Whether to show line numbers (default: false)
      #
      # @example Register a simple code block
      #   register_code_block_handler(:python)
      #   # => caption_index: 0, lang_index: 1, default_lang: 'python'
      #
      # @example Register a code block with line numbers
      #   register_code_block_handler(:pythonnum,
      #     line_numbers: true,
      #     default_lang: 'python'
      #   )
      #
      # @example Register a list-style code block with ID
      #   register_code_block_handler(:mylist,
      #     id_index: 0,
      #     caption_index: 1,
      #     lang_index: 2
      #   )
      def register_code_block_handler(command_name, config = {})
        # Provide sensible defaults
        default_config = {
          caption_index: 0,
          lang_index: 1,
          default_lang: command_name.to_s
        }
        merged_config = default_config.merge(config)

        # Register the configuration
        @dynamic_code_block_configs[command_name] = merged_config

        # Register the command handler to use build_code_block_ast
        @dynamic_command_table[command_name] = :build_code_block_ast

        merged_config
      end

      # Register a new code block configuration
      # @param command_name [Symbol] The code block command name (e.g., :python)
      # @param config [Hash] The configuration hash with keys like :id_index, :caption_index, :lang_index, :line_numbers, :default_lang
      # @example
      #   register_code_block_config(:python, { id_index: 0, caption_index: 1, lang_index: 2 })
      def register_code_block_config(command_name, config)
        @dynamic_code_block_configs[command_name] = config
      end

      # @return [Hash] Hash of all registered code block configs
      def registered_code_block_configs
        @dynamic_code_block_configs.dup
      end

      # Unified entry point - table-driven block processing
      # Receives BlockData and calls corresponding method based on dynamic command table
      def process_block_command(block_data)
        handler_method = @dynamic_command_table[block_data.name]

        unless handler_method
          raise CompileError, "Unknown block command: //#{block_data.name}#{format_location_info(block_data.location)}"
        end

        # Process block using Block-Scoped Compilation
        @ast_compiler.with_block_context(block_data) do |context|
          send(handler_method, context)
        end
      end

      def compile_code_block_to_ast(type, args, lines)
        create_code_block_node(type, args, lines)
      end

      def compile_image_to_ast(type, args)
        caption_data = process_caption(args, 1)

        create_and_add_node(AST::ImageNode,
                            id: args[0],
                            caption: caption_text(caption_data),
                            caption_node: caption_node(caption_data),
                            metric: args[2],
                            image_type: type)
      end

      def compile_table_to_ast(type, args, lines)
        node = case type
               when :table
                 caption_data = process_caption(args, 1)
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: caption_text(caption_data),
                             caption_node: caption_node(caption_data),
                             table_type: :table)
               when :emtable
                 caption_data = process_caption(args, 0)
                 create_node(AST::TableNode,
                             id: nil, # emtable has no ID
                             caption: caption_text(caption_data),
                             caption_node: caption_node(caption_data),
                             table_type: :emtable)
               when :imgtable
                 caption_data = process_caption(args, 1)
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: caption_text(caption_data),
                             caption_node: caption_node(caption_data),
                             table_type: :imgtable,
                             metric: args[2])
               else
                 caption_data = process_caption(args, 1)
                 # Fallback for unknown table types
                 create_node(AST::TableNode,
                             id: args[0],
                             caption: caption_text(caption_data),
                             caption_node: caption_node(caption_data),
                             table_type: type)
               end

        if lines
          separator_index = lines.find_index { |line| line.match?(/\A[=-]{12}/) || line.match?(/\A[={}-]{12}/) }

          # Process header rows
          if separator_index
            header_lines = lines[0...separator_index]
            header_lines.each do |line|
              row_node = create_table_row_from_line(line, is_header: true, block_location: @ast_compiler.location)
              node.add_header_row(row_node)
            end

            # Process body rows
            body_lines = lines[(separator_index + 1)..-1] || []
            body_lines.each do |line|
              row_node = create_table_row_from_line(line, first_cell_header: false, block_location: @ast_compiler.location)
              node.add_body_row(row_node)
            end
          else
            # No separator, all lines are body rows with first cell as header
            lines.each do |line|
              row_node = create_table_row_from_line(line, first_cell_header: true, block_location: @ast_compiler.location)
              node.add_body_row(row_node)
            end
          end
        end

        add_node_to_ast(node)
      end

      def compile_list_to_ast(type, lines)
        # Create list node and add items as children
        list_node = create_and_add_node(AST::ListNode, list_type: type)

        lines.each do |line|
          item_node = create_node(AST::ListItemNode,
                                  content: line,
                                  level: 1)
          list_node.add_child(item_node)
        end

        list_node
      end

      def compile_block_to_ast(lines, block_type)
        # Create a BlockNode for quote blocks and other block types
        node = AST::BlockNode.new(
          location: @ast_compiler.location,
          block_type: block_type
        )

        if lines && lines.any?
          # Use the universal block processing method for structured content like lists and paragraphs
          case block_type
          when :quote, :lead, :blockquote, :read, :centering, :flushright, :address, :talk
            # These block types can contain structured content (paragraphs, lists)
            @ast_compiler.process_structured_content(node, lines)
          else
            # For other block types, use simple inline processing
            lines.each { |line| @ast_compiler.inline_processor.parse_inline_elements(line, node) }
          end
        end

        @ast_compiler.add_child_to_current_node(node)
      end

      def compile_minicolumn_to_ast(type, args, lines)
        # Handle both 1-arg and 2-arg minicolumn syntax
        if args.length >= 2
          # 2-argument form: [id][caption]
          id = args[0]
          caption_index = 1
        else
          # 1-argument form: [caption]
          id = nil
          caption_index = 0
        end

        # Create a MinicolumnNode for note, memo, tip, etc.
        caption_data = process_caption(args, caption_index)

        node = AST::MinicolumnNode.new(
          location: @ast_compiler.location,
          minicolumn_type: type.to_sym,
          id: id,
          caption: caption_text(caption_data),
          caption_node: caption_node(caption_data)
        )

        # Use the universal block processing method from Compiler for HTML Builder compatibility
        # This processes content using the same logic as regular document processing
        @ast_compiler.process_structured_content(node, lines)

        @ast_compiler.add_child_to_current_node(node)
      end

      def compile_embed_to_ast(args, lines)
        node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :block,
          arg: args[0],
          lines: lines || []
        )

        @ast_compiler.add_child_to_current_node(node)
      end

      def compile_footnote_to_ast(command_name, args, lines)
        build_footnote_ast(command_name, args, lines)
      end

      private

      # New methods supporting BlockData

      # Use BlockContext for consistent location information in AST construction
      def build_code_block_ast(context)
        config = @dynamic_code_block_configs[context.name]
        unless config
          raise CompileError, "Unknown code block type: #{context.name}#{context.format_location_info}"
        end

        # Preserve original text
        original_text = context.lines ? context.lines.join("\n") : ''

        caption_data = context.process_caption(context.args, config[:caption_index])

        # Create node using BlockContext (location automatically set to block start position)
        node = context.create_node(AST::CodeBlockNode,
                                   id: context.arg(config[:id_index]),
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data),
                                   lang: context.arg(config[:lang_index]) || config[:default_lang],
                                   line_numbers: config[:line_numbers] || false,
                                   code_type: context.name,
                                   original_text: original_text)

        # Process main content
        if context.content?
          context.lines.each_with_index do |line, index|
            line_node = context.create_node(AST::CodeLineNode,
                                            line_number: config[:line_numbers] ? index + 1 : nil,
                                            original_text: line)

            # When inline processing is needed (BlockContext properly manages location information)
            if builder_needs_inline_processing?
              context.process_inline_elements(line, line_node)
            else
              text_node = context.create_node(AST::TextNode, content: line)
              line_node.add_child(text_node)
            end

            node.add_child(line_node)
          end
        end

        # Process nested blocks
        context.process_nested_blocks(node)

        # Add node to current AST
        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_image_ast(context)
        caption_data = context.process_caption(context.args, 1)

        node = context.create_node(AST::ImageNode,
                                   id: context.arg(0),
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data),
                                   metric: context.arg(2),
                                   image_type: context.name)
        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_table_ast(context)
        node = case context.name
               when :table
                 caption_data = context.process_caption(context.args, 1)
                 context.create_node(AST::TableNode,
                                     id: context.arg(0),
                                     caption: caption_text(caption_data),
                                     caption_node: caption_node(caption_data),
                                     table_type: :table)
               when :emtable
                 caption_data = context.process_caption(context.args, 0)
                 context.create_node(AST::TableNode,
                                     id: nil,
                                     caption: caption_text(caption_data),
                                     caption_node: caption_node(caption_data),
                                     table_type: :emtable)
               when :imgtable
                 caption_data = context.process_caption(context.args, 1)
                 context.create_node(AST::TableNode,
                                     id: context.arg(0),
                                     caption: caption_text(caption_data),
                                     caption_node: caption_node(caption_data),
                                     table_type: :imgtable,
                                     metric: context.arg(2))
               else
                 caption_data = context.process_caption(context.args, 1)
                 context.create_node(AST::TableNode,
                                     id: context.arg(0),
                                     caption: caption_text(caption_data),
                                     caption_node: caption_node(caption_data),
                                     table_type: context.name)
               end

        # Validate and process table rows
        # Check for empty table first (before context.content? check)
        # Note: imgtable can be empty as it embeds an image file, not table data
        if !context.content? || context.lines.nil? || context.lines.empty?
          unless context.name == :imgtable
            raise ReVIEW::CompileError, 'no rows in the table'
          end
        else
          # Process table content only if not empty
          process_table_content(node, context.lines, context.start_location)
        end

        # Process nested blocks
        context.process_nested_blocks(node)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Build list with support for both simple lines and //li blocks
      def build_list_ast(context)
        list_node = context.create_node(AST::ListNode, list_type: context.name)

        # Process text content as simple list items
        if context.content?
          context.lines.each do |line|
            item_node = context.create_node(AST::ListItemNode,
                                            content: line,
                                            level: 1)
            list_node.add_child(item_node)
          end
        end

        # Process nested blocks (including //li blocks)
        context.process_nested_blocks(list_node)

        @ast_compiler.add_child_to_current_node(list_node)
        list_node
      end

      # Build individual list item with nested content support
      def build_list_item_ast(context)
        # Validate that //li is inside a list block
        parent_node = @ast_compiler.current_ast_node
        unless parent_node.is_a?(AST::ListNode)
          raise CompileError, "//li must be inside //ul, //ol, or //dl block#{context.format_location_info}"
        end

        # Create list item node - simple, no complex title handling
        item_node = context.create_node(AST::ListItemNode, level: 1)

        # Process content using the same structured content processing as other blocks
        # This handles paragraphs, nested lists, and block elements naturally
        if context.content?
          @ast_compiler.process_structured_content(item_node, context.lines)
        end

        # Process nested blocks within this item
        context.process_nested_blocks(item_node)

        # Add to parent (should be a list node)
        @ast_compiler.add_child_to_current_node(item_node)
        item_node
      end

      # Build definition term (//dt) for definition lists
      def build_definition_term_ast(context)
        # Validate that //dt is inside a //dl block
        parent_node = @ast_compiler.current_ast_node
        unless parent_node.is_a?(AST::ListNode) && parent_node.list_type == :dl
          raise CompileError, "//dt must be inside //dl block#{context.format_location_info}"
        end

        # Create list item node with dt type
        item_node = context.create_node(AST::ListItemNode, level: 1, item_type: :dt)

        # Process content
        if context.content?
          @ast_compiler.process_structured_content(item_node, context.lines)
        end

        # Process nested blocks
        context.process_nested_blocks(item_node)

        # Add to parent (should be a dl list node)
        @ast_compiler.add_child_to_current_node(item_node)
        item_node
      end

      # Build definition description (//dd) for definition lists
      def build_definition_desc_ast(context)
        # Validate that //dd is inside a //dl block
        parent_node = @ast_compiler.current_ast_node
        unless parent_node.is_a?(AST::ListNode) && parent_node.list_type == :dl
          raise CompileError, "//dd must be inside //dl block#{context.format_location_info}"
        end

        # Create list item node with dd type
        item_node = context.create_node(AST::ListItemNode, level: 1, item_type: :dd)

        # Process content
        if context.content?
          @ast_compiler.process_structured_content(item_node, context.lines)
        end

        # Process nested blocks
        context.process_nested_blocks(item_node)

        # Add to parent (should be a dl list node)
        @ast_compiler.add_child_to_current_node(item_node)
        item_node
      end

      # Build minicolumn (with nesting support)
      def build_minicolumn_ast(context)
        # Check for nested minicolumn - traverse up the AST to find any minicolumn ancestor
        current_node = @ast_compiler.current_ast_node
        while current_node
          if current_node.is_a?(AST::MinicolumnNode)
            @ast_compiler.error("minicolumn cannot be nested: //#{context.name}")
            # Continue processing without creating the nested minicolumn
            # (same as Builder pattern - log error and continue)
            return
          end
          current_node = current_node.parent
        end

        # Handle both 1-arg and 2-arg minicolumn syntax
        # //note[caption]{ ... }         - 1 arg: caption only
        # //note[id][caption]{ ... }     - 2 args: id and caption
        if context.args.length >= 2
          # 2-argument form: [id][caption]
          id = context.arg(0)
          caption_index = 1
        else
          # 1-argument form: [caption]
          id = nil
          caption_index = 0
        end

        caption_data = context.process_caption(context.args, caption_index)

        node = context.create_node(AST::MinicolumnNode,
                                   minicolumn_type: context.name,
                                   id: id,
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data))

        # Process structured content
        context.process_structured_content_with_blocks(node)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_column_ast(context)
        caption_data = context.process_caption(context.args, 1)

        node = context.create_node(AST::ColumnNode,
                                   level: 2, # Default level for block columns
                                   label: context.arg(0),
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data),
                                   column_type: 'column')

        # Process structured content
        context.process_structured_content_with_blocks(node)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_quote_block_ast(context)
        node = context.create_node(AST::BlockNode, block_type: context.name)

        # Process structured content and nested blocks
        if context.nested_blocks?
          context.process_structured_content_with_blocks(node)
        elsif context.content?
          case context.name
          when :quote, :lead, :blockquote, :read, :centering, :flushright, :address, :talk
            @ast_compiler.process_structured_content(node, context.lines)
          else
            context.lines.each { |line| context.process_inline_elements(line, node) }
          end
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_complex_block_ast(context)
        # For syntaxblock types (box, insn) and captionblock types (point, term),
        # preserve the original lines array for proper formatting
        preserve_lines = %i[box insn point term].include?(context.name)

        # Determine caption index based on block type
        caption_index = case context.name
                        when :graph
                          2 # //graph[id][command][caption]
                        when :bibpaper
                          1 # //bibpaper[id][caption]
                        when :doorquote, :point, :shoot, :term, :box, :insn
                          0 # //doorquote[caption], //point[caption], //box[caption], etc.
                        end

        # Process caption if applicable
        caption_data = caption_index ? context.process_caption(context.args, caption_index) : nil

        node = context.create_node(AST::BlockNode,
                                   block_type: context.name,
                                   args: context.args,
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data),
                                   lines: preserve_lines ? context.lines.dup : nil)

        # Process content and nested blocks
        if context.nested_blocks?
          context.process_structured_content_with_blocks(node)
        elsif context.content?
          context.lines.each do |line|
            context.process_inline_elements(line, node)
          end
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_control_command_ast(context)
        case context.name
        when :texequation
          build_tex_equation_ast(context)
        else
          node = context.create_node(AST::BlockNode,
                                     block_type: context.name,
                                     args: context.args)

          if context.content?
            context.lines.each do |line|
              text_node = context.create_node(AST::TextNode, content: line)
              node.add_child(text_node)
            end
          end

          @ast_compiler.add_child_to_current_node(node)
          node
        end
      end

      def build_tex_equation_ast(context)
        require 'review/ast/tex_equation_node'

        # Collect all LaTeX content lines
        latex_content = if context.content?
                          context.lines.join("\n") + "\n"
                        else
                          ''
                        end

        caption_data = context.process_caption(context.args, 1)

        node = context.create_node(AST::TexEquationNode,
                                   id: context.arg(0),
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data),
                                   latex_content: latex_content)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_raw_ast(context)
        raw_content = context.arg(0) || ''
        target_builders, content = parse_raw_content(raw_content)

        node = context.create_node(AST::EmbedNode,
                                   embed_type: :raw,
                                   lines: context.lines || [],
                                   arg: raw_content,
                                   target_builders: target_builders,
                                   content: content)

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_embed_ast(context)
        node = context.create_node(AST::EmbedNode,
                                   embed_type: :block,
                                   arg: context.arg(0),
                                   lines: context.lines || [])

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      def build_footnote_ast(context)
        footnote_id = context.arg(0)
        footnote_content = context.arg(1) || ''

        node = context.create_node(AST::FootnoteNode,
                                   id: footnote_id,
                                   footnote_type: context.name)

        if footnote_content && !footnote_content.empty?
          context.process_inline_elements(footnote_content, node)
        end

        @ast_compiler.add_child_to_current_node(node)
        node
      end

      # Process nested blocks
      def process_nested_blocks(parent_node, block_data)
        return unless block_data.nested_blocks?

        # Use public API to temporarily change current node
        @ast_compiler.with_temporary_ast_node!(parent_node) do
          # Process nested blocks recursively
          block_data.nested_blocks.each do |nested_block|
            process_block_command(nested_block)
          end
        end
      end

      # Process structured content including nested blocks
      def process_structured_content_with_blocks(parent_node, block_data)
        # Process regular lines
        @ast_compiler.process_structured_content(parent_node, block_data.lines) if block_data.content?

        # Process nested blocks
        process_nested_blocks(parent_node, block_data)
      end

      # Process table content
      def process_table_content(table_node, lines, block_location = nil)
        # Check for empty table
        if lines.nil? || lines.empty?
          raise ReVIEW::CompileError, 'no rows in the table'
        end

        separator_index = lines.find_index { |line| line.match?(/\A[=-]{12}/) || line.match?(/\A[={}-]{12}/) }

        # Check if table only contains separator (no actual data rows)
        if separator_index && separator_index == 0 && lines.length == 1
          raise ReVIEW::CompileError, 'no rows in the table'
        end

        # Create row nodes first, then adjust columns
        header_rows = []
        body_rows = []

        if separator_index
          # Process header rows
          header_lines = lines[0...separator_index]
          header_lines.each do |line|
            row_node = create_table_row_from_line(line, is_header: true, block_location: block_location)
            header_rows << row_node
          end

          # Process body rows
          body_lines = lines[(separator_index + 1)..-1] || []
          body_lines.each do |line|
            row_node = create_table_row_from_line(line, first_cell_header: false, block_location: block_location)
            body_rows << row_node
          end
        else
          # No separator - all body rows (first cell as header)
          lines.each do |line|
            row_node = create_table_row_from_line(line, first_cell_header: true, block_location: block_location)
            body_rows << row_node
          end
        end

        # Adjust column count to match Builder behavior
        adjust_table_columns(header_rows + body_rows)

        # Add rows to table node
        header_rows.each { |row| table_node.add_header_row(row) }
        body_rows.each { |row| table_node.add_body_row(row) }
      end

      # Adjust table row columns to ensure all rows have the same number of columns
      # Matches the behavior of Builder#adjust_n_cols
      def adjust_table_columns(rows)
        return if rows.empty?

        # Remove trailing empty cells from each row
        rows.each do |row|
          while row.children.last && row.children.last.children.empty?
            row.children.pop
          end
        end

        # Find maximum column count
        max_cols = rows.map { |row| row.children.size }.max

        # Add empty cells to rows that need them
        rows.each do |row|
          cells_needed = max_cols - row.children.size
          cells_needed.times do
            # Determine cell type based on whether this is a header row
            # Check if first cell is :th to determine if this is a header row
            cell_type = row.children.first&.cell_type == :th ? :th : :td
            empty_cell = create_node(AST::TableCellNode, cell_type: cell_type)
            row.add_child(empty_cell)
          end
        end
      end

      # Format location information for error messages
      def format_location_info(location = nil)
        location ||= @ast_compiler.location
        return '' unless location

        info = " at line #{location.lineno}"
        info += " in #{location.filename}" if location.filename
        info
      end

      # Common AST node creation helpers

      # Create any AST node with location automatically set
      def create_node(node_class, **attributes)
        node_class.new(location: @ast_compiler.location, **attributes)
      end

      # Create AST node and add to current node in one step
      def create_and_add_node(node_class, **attributes)
        node = create_node(node_class, **attributes)
        add_node_to_ast(node)
        node
      end

      # Add node to current AST node
      def add_node_to_ast(node)
        @ast_compiler.add_child_to_current_node(node)
      end

      # Create text node with content
      def create_text_node(content)
        create_node(AST::TextNode, content: content)
      end

      # Unified factory method for creating code block nodes
      def create_code_block_node(command_type, args, lines)
        config = @dynamic_code_block_configs[command_type]
        unless config
          raise ArgumentError, "Unknown code block type: #{command_type}#{format_location_info}"
        end

        # Preserve original text for builders that don't need inline processing
        original_text = lines ? lines.join("\n") : ''

        caption_data = process_caption(args, config[:caption_index])

        node = create_and_add_node(AST::CodeBlockNode,
                                   id: safe_arg(args, config[:id_index]),
                                   caption: caption_text(caption_data),
                                   caption_node: caption_node(caption_data),
                                   lang: safe_arg(args, config[:lang_index]) || config[:default_lang],
                                   line_numbers: config[:line_numbers] || false,
                                   code_type: command_type,
                                   original_text: original_text)

        # Process each line and create CodeLineNode
        if lines
          lines.each_with_index do |line, index|
            line_node = create_node(AST::CodeLineNode,
                                    line_number: config[:line_numbers] ? index + 1 : nil,
                                    original_text: line)

            # Check if this builder needs inline processing
            if builder_needs_inline_processing?
              # Parse inline elements in code line
              @ast_compiler.inline_processor.parse_inline_elements(line, line_node)
            else
              # Create simple TextNode for the entire line
              text_node = create_node(AST::TextNode, content: line)
              line_node.add_child(text_node)
            end

            node.add_child(line_node)
          end
        end

        node
      end

      def process_caption(args, caption_index, location = nil)
        return nil if caption_index.nil?

        caption_text = safe_arg(args, caption_index)
        return nil if caption_text.nil?

        # Location information priority: argument > @ast_compiler.location
        caption_location = location || @ast_compiler.location

        caption_node = AST::CaptionNode.new(location: caption_location)

        begin
          @ast_compiler.with_temporary_location!(caption_location) do
            @ast_compiler.inline_processor.parse_inline_elements(caption_text, caption_node)
          end
        rescue StandardError => e
          raise CompileError, "Error processing caption '#{caption_text}': #{e.message}#{format_location_info(caption_location)}"
        end

        { text: caption_text, node: caption_node }
      end

      def caption_text(caption_data)
        caption_data && caption_data[:text]
      end

      def caption_node(caption_data)
        caption_data && caption_data[:node]
      end

      # Extract argument safely
      def safe_arg(args, index)
        return nil unless args && index && index.is_a?(Integer) && index >= 0 && args.size > index

        args[index]
      end

      # Check if the current builder needs inline processing in code blocks
      def builder_needs_inline_processing?
        # Always process inline elements to generate unified AST structure
        # Individual builders will decide how to interpret them
        true
      end

      # Get the regular expression for table row separator based on config
      # Matches the logic in Builder#table_row_separator_regexp
      def table_row_separator_regexp
        # Get config from chapter's book (same as Builder pattern)
        # Handle cases where chapter or book may not exist (e.g., in tests)
        chapter = @ast_compiler.chapter
        config = if chapter && chapter.respond_to?(:book) && chapter.book
                   chapter.book.config || {}
                 else
                   {}
                 end

        case config['table_row_separator']
        when 'singletab'
          /\t/
        when 'spaces'
          /\s+/
        when 'verticalbar'
          /\s*\|\s*/
        else
          # Default: 'tabs' or nil - consecutive tabs treated as one separator
          /\t+/
        end
      end

      # Create a table row node from a line containing tab-separated cells
      # The is_header parameter determines if all cells should be header cells
      # The first_cell_header parameter determines if only the first cell should be a header
      def create_table_row_from_line(line, is_header: false, first_cell_header: false, block_location: nil)
        row_node = create_node(AST::TableRowNode, row_type: is_header ? :header : :body)

        # Split by configured separator to get cells
        cells = line.strip.split(table_row_separator_regexp).map { |s| s.sub(/\A\./, '') }
        if cells.empty?
          error_location = block_location || @ast_compiler.location
          raise CompileError, "Invalid table row: empty line or no tab-separated cells#{format_location_info(error_location)}"
        end

        cells.each_with_index do |cell_content, index|
          # Determine cell type based on row context and position
          cell_type = if is_header
                        :th # All cells in header rows are <th>
                      elsif first_cell_header && index == 0 # rubocop:disable Lint/DuplicateBranch
                        :th  # First cell in non-header rows is <th> (row header)
                      else
                        :td  # Regular data cells
                      end

          cell_node = create_node(AST::TableCellNode, cell_type: cell_type)

          # Parse inline elements in cell content
          # Note: prefix "." has already been removed during split
          @ast_compiler.inline_processor.parse_inline_elements(cell_content, cell_node)

          row_node.add_child(cell_node)
        end

        row_node
      end

      def parse_raw_content(content)
        return [nil, content] if content.nil? || content.empty?

        # Check for builder specification: |builder1,builder2|content
        if matched = content.match(/\A\|(.*?)\|(.*)/)
          builders = matched[1].split(',').map { |i| i.gsub(/\s/, '') }
          processed_content = matched[2]
          [builders, processed_content]
        else
          # No builder specification - target all builders
          [nil, content]
        end
      end

      CODE_BLOCK_CONFIGS = { # rubocop:disable Lint/UselessConstantScoping
        list: { id_index: 0, caption_index: 1, lang_index: 2 },
        listnum: { id_index: 0, caption_index: 1, lang_index: 2, line_numbers: true },
        emlist: { caption_index: 0, lang_index: 1 },
        emlistnum: { caption_index: 0, lang_index: 1, line_numbers: true },
        cmd: { caption_index: 0, default_lang: 'shell' },
        source: { caption_index: 0, lang_index: 1 }
      }.freeze

      BLOCK_COMMAND_TABLE = { # rubocop:disable Lint/UselessConstantScoping
        # Code blocks
        list: :build_code_block_ast,
        listnum: :build_code_block_ast,
        emlist: :build_code_block_ast,
        emlistnum: :build_code_block_ast,
        cmd: :build_code_block_ast,
        source: :build_code_block_ast,

        # Media blocks
        image: :build_image_ast,
        indepimage: :build_image_ast,
        numberlessimage: :build_image_ast,

        # Table blocks
        table: :build_table_ast,
        emtable: :build_table_ast,
        imgtable: :build_table_ast,

        # Simple list blocks (//ul, //ol, //dl commands)
        ul: :build_list_ast,
        ol: :build_list_ast,
        dl: :build_list_ast,

        # List item blocks (//li command for use within lists)
        li: :build_list_item_ast,

        # Definition list blocks (//dt and //dd for use within //dl)
        dt: :build_definition_term_ast,
        dd: :build_definition_desc_ast,

        # Minicolumn blocks
        note: :build_minicolumn_ast,
        memo: :build_minicolumn_ast,
        tip: :build_minicolumn_ast,
        info: :build_minicolumn_ast,
        warning: :build_minicolumn_ast,
        important: :build_minicolumn_ast,
        caution: :build_minicolumn_ast,
        notice: :build_minicolumn_ast,

        # Column blocks
        column: :build_column_ast,

        # Reference blocks
        footnote: :build_footnote_ast,
        endnote: :build_footnote_ast,

        # Embed blocks
        embed: :build_embed_ast,
        raw: :build_raw_ast,

        # Quote and content blocks
        read: :build_quote_block_ast,
        quote: :build_quote_block_ast,
        blockquote: :build_quote_block_ast,
        lead: :build_quote_block_ast,
        centering: :build_quote_block_ast,
        flushright: :build_quote_block_ast,
        address: :build_quote_block_ast,
        talk: :build_quote_block_ast,

        # Complex blocks
        doorquote: :build_complex_block_ast,
        bibpaper: :build_complex_block_ast,
        graph: :build_complex_block_ast,
        box: :build_complex_block_ast,
        insn: :build_complex_block_ast,
        point: :build_complex_block_ast,
        term: :build_complex_block_ast,

        # Control commands
        comment: :build_control_command_ast,
        olnum: :build_control_command_ast,
        blankline: :build_control_command_ast,
        noindent: :build_control_command_ast,
        pagebreak: :build_control_command_ast,
        firstlinenum: :build_control_command_ast,
        tsize: :build_control_command_ast,
        label: :build_control_command_ast,
        printendnotes: :build_control_command_ast,
        hr: :build_control_command_ast,
        bpo: :build_control_command_ast,
        parasep: :build_control_command_ast,
        beginchild: :build_control_command_ast,
        endchild: :build_control_command_ast,

        # Math blocks
        texequation: :build_tex_equation_ast
      }.freeze
    end
  end
end
