# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/ast/block_data'
require 'review/ast/block_processor/code_block_structure'
require 'review/ast/block_processor/table_processor'
require 'review/ast/raw_content_parser'
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

      @configuration_blocks = []

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
          @configuration_blocks << block if block
        end

        # Get all registered configuration blocks (for testing)
        # @return [Array<Proc>] Array of configuration blocks
        def configuration_blocks
          @configuration_blocks.dup
        end

        # Clear all registered configuration blocks (for testing)
        # @return [void]
        def clear_configuration!
          @configuration_blocks = []
        end
      end

      def initialize(ast_compiler)
        @ast_compiler = ast_compiler
        @table_processor = TableProcessor.new(ast_compiler)
        @dynamic_command_table = BLOCK_COMMAND_TABLE.dup
        @dynamic_code_block_configs = CODE_BLOCK_CONFIGS.dup

        apply_configuration
      end

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
          location_info = block_data.location.format_for_error
          raise CompileError, "Unknown block command: //#{block_data.name}#{location_info}"
        end

        # Process block using Block-Scoped Compilation
        @ast_compiler.with_block_context(block_data) do |context|
          send(handler_method, context)
        end
      end

      private

      def apply_configuration
        config = Configuration.new(self)
        self.class.configuration_blocks.each do |block|
          block.call(config)
        end
      end

      def build_code_block_ast(context)
        config = @dynamic_code_block_configs[context.name]
        unless config
          raise CompileError, "Unknown code block type: #{context.name}#{context.start_location.format_for_error}"
        end

        structure = CodeBlockStructure.from_context(context, config)
        context.append_new_node(AST::CodeBlockNode,
                                id: structure.id,
                                caption_node: structure.caption_node,
                                lang: structure.lang,
                                line_numbers: structure.line_numbers,
                                code_type: structure.code_type,
                                original_text: structure.original_text) do |node|
          if structure.content?
            structure.lines.each_with_index do |line, index|
              line_node = context.create_node(AST::CodeLineNode,
                                              line_number: structure.numbered? ? index + 1 : nil,
                                              original_text: line)

              context.process_inline_elements(line, line_node)

              node.add_child(line_node)
            end
          end

          context.process_nested_blocks(node)
        end
      end

      def build_image_ast(context)
        caption_node = context.process_caption(context.args, 1)

        context.append_new_node(AST::ImageNode,
                                id: context.arg(0),
                                caption_node: caption_node,
                                metric: context.arg(2),
                                image_type: context.name)
      end

      def build_table_ast(context)
        @table_processor.build_table_node(context)
      end

      # Build list with support for both simple lines and //li blocks
      def build_list_ast(context)
        context.append_new_node(AST::ListNode, list_type: context.name) do |list_node|
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
        end
      end

      # Build individual list item with nested content support
      def build_list_item_ast(context)
        # Validate that //li is inside a list block
        parent_node = @ast_compiler.current_ast_node
        unless parent_node.is_a?(AST::ListNode)
          raise CompileError, "//li must be inside //ul, //ol, or //dl block#{context.start_location.format_for_error}"
        end

        context.append_new_node(AST::ListItemNode, level: 1) do |item_node|
          # Process content using the same structured content processing as other blocks
          # This handles paragraphs, nested lists, and block elements naturally
          if context.content?
            @ast_compiler.process_structured_content(item_node, context.lines)
          end

          # Process nested blocks within this item
          context.process_nested_blocks(item_node)
        end
      end

      # Build definition term (//dt) for definition lists
      def build_definition_term_ast(context)
        # Validate that //dt is inside a //dl block
        parent_node = @ast_compiler.current_ast_node
        unless parent_node.is_a?(AST::ListNode) && parent_node.list_type == :dl
          raise CompileError, "//dt must be inside //dl block#{context.start_location.format_for_error}"
        end

        context.append_new_node(AST::ListItemNode, level: 1, item_type: :dt) do |item_node|
          # Process content
          if context.content?
            @ast_compiler.process_structured_content(item_node, context.lines)
          end

          # Process nested blocks
          context.process_nested_blocks(item_node)
        end
      end

      # Build definition description (//dd) for definition lists
      def build_definition_desc_ast(context)
        # Validate that //dd is inside a //dl block
        parent_node = @ast_compiler.current_ast_node
        unless parent_node.is_a?(AST::ListNode) && parent_node.list_type == :dl
          raise CompileError, "//dd must be inside //dl block#{context.start_location.format_for_error}"
        end

        context.append_new_node(AST::ListItemNode, level: 1, item_type: :dd) do |item_node|
          # Process content
          if context.content?
            @ast_compiler.process_structured_content(item_node, context.lines)
          end

          # Process nested blocks
          context.process_nested_blocks(item_node)
        end
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

        caption_node = context.process_caption(context.args, caption_index)

        context.append_new_node(AST::MinicolumnNode,
                                minicolumn_type: context.name,
                                id: id,
                                caption_node: caption_node) do |node|
          # Process structured content
          context.process_structured_content_with_blocks(node)
        end
      end

      def build_column_ast(context)
        caption_node = context.process_caption(context.args, 1)

        context.append_new_node(AST::ColumnNode,
                                level: 2, # Default level for block columns
                                label: context.arg(0),
                                caption_node: caption_node,
                                column_type: :column) do |node|
          # Process structured content
          context.process_structured_content_with_blocks(node)
        end
      end

      def build_quote_block_ast(context)
        context.append_new_node(AST::BlockNode, block_type: context.name) do |node|
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
        end
      end

      def build_complex_block_ast(context)
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
        caption_node = caption_index ? context.process_caption(context.args, caption_index) : nil

        context.append_new_node(AST::BlockNode,
                                block_type: context.name,
                                args: context.args,
                                caption_node: caption_node) do |node|
          # Process content and nested blocks
          if context.nested_blocks?
            context.process_structured_content_with_blocks(node)
          elsif context.content?
            case context.name
            when :box, :insn
              # Line-based processing for box/insn - preserve each line as separate node
              context.lines.each do |line|
                # Create a paragraph node for each line (including empty lines)
                # This preserves line structure for listinfo processing
                para_node = context.create_node(AST::ParagraphNode)
                context.process_inline_elements(line, para_node) unless line.empty?
                node.add_child(para_node)
              end
            when :point, :shoot, :term
              # Paragraph-based processing for point/shoot/term
              # Empty lines separate paragraphs
              @ast_compiler.process_structured_content(node, context.lines)
            else
              # Default: inline processing for each line
              context.lines.each do |line|
                context.process_inline_elements(line, node)
              end
            end
          end
        end
      end

      def build_control_command_ast(context)
        context.append_new_node(AST::BlockNode,
                                block_type: context.name,
                                args: context.args) do |node|
          if context.content?
            context.lines.each do |line|
              text_node = context.create_node(AST::TextNode, content: line)
              node.add_child(text_node)
            end
          end
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

        caption_node = context.process_caption(context.args, 1)

        context.append_new_node(AST::TexEquationNode,
                                id: context.arg(0),
                                caption_node: caption_node,
                                latex_content: latex_content)
      end

      def build_raw_ast(context)
        raw_content = context.arg(0) || ''
        target_builders, content = RawContentParser.parse(raw_content)

        context.append_new_node(AST::EmbedNode,
                                embed_type: :raw,
                                lines: context.lines || [],
                                arg: raw_content,
                                target_builders: target_builders,
                                content: content)
      end

      def build_embed_ast(context)
        context.append_new_node(AST::EmbedNode,
                                embed_type: :block,
                                arg: context.arg(0),
                                lines: context.lines || [])
      end

      def build_footnote_ast(context)
        footnote_id = context.arg(0)
        footnote_content = context.arg(1) || ''

        context.append_new_node(AST::FootnoteNode,
                                id: footnote_id,
                                footnote_type: context.name) do |node|
          if footnote_content && !footnote_content.empty?
            context.process_inline_elements(footnote_content, node)
          end
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
