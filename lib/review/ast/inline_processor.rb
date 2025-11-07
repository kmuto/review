# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require_relative 'inline_tokenizer'
require_relative 'reference_node'
require_relative 'raw_content_parser'

module ReVIEW
  module AST
    # InlineProcessor - Inline element parsing and AST node creation
    #
    # This class handles the complex parsing of Re:VIEW inline elements
    # and converts them to appropriate AST nodes with proper nesting.
    #
    # Responsibilities:
    # - Parse inline markup (@<command>{content}) within text
    # - Create appropriate AST nodes for different inline types
    # - Handle nested inline elements
    # - Process specialized inline formats (ruby, href, kw, etc.)
    class InlineProcessor
      # Default mapping of inline commands to handler methods
      DEFAULT_INLINE_HANDLERS = {
        embed: :create_inline_embed_ast_node,
        ruby: :create_inline_ruby_ast_node,
        href: :create_inline_href_ast_node,
        kw: :create_inline_kw_ast_node,
        img: :create_inline_ref_ast_node,
        imgref: :create_inline_ref_ast_node,
        list: :create_inline_ref_ast_node,
        table: :create_inline_ref_ast_node,
        eq: :create_inline_ref_ast_node,
        fn: :create_inline_ref_ast_node,
        endnote: :create_inline_ref_ast_node,
        column: :create_inline_ref_ast_node,
        w: :create_inline_ref_ast_node,
        wb: :create_inline_ref_ast_node,
        bib: :create_inline_ref_ast_node,
        bibref: :create_inline_ref_ast_node,
        hd: :create_inline_cross_ref_ast_node,
        chap: :create_inline_cross_ref_ast_node,
        chapref: :create_inline_cross_ref_ast_node,
        title: :create_inline_cross_ref_ast_node,
        sec: :create_inline_cross_ref_ast_node,
        secref: :create_inline_cross_ref_ast_node,
        sectitle: :create_inline_cross_ref_ast_node,
        labelref: :create_inline_cross_ref_ast_node,
        ref: :create_inline_cross_ref_ast_node,
        raw: :create_inline_raw_ast_node
      }.freeze

      def initialize(ast_compiler)
        @ast_compiler = ast_compiler
        @tokenizer = InlineTokenizer.new
        # Copy the static table to allow runtime modifications
        @inline_handlers = DEFAULT_INLINE_HANDLERS.dup
      end

      # Parse inline elements and create AST nodes
      def parse_inline_elements(str, parent_node)
        return if str.empty?

        # Use tokenizer to parse both fence syntax (@<cmd>$...$, @<cmd>|...|) and brace syntax (@<cmd>{...})
        tokens = @tokenizer.tokenize(str, location: @ast_compiler.location)

        tokens.each do |token|
          if token.type == :inline
            create_inline_ast_node_from_token(token, parent_node)
          else
            # Plain text
            unless token.content.empty?
              text_node = AST::TextNode.new(
                location: @ast_compiler.location,
                content: token.content
              )
              parent_node.add_child(text_node)
            end
          end
        end
      end

      # Register a new inline command handler
      # @param command [Symbol] The inline command name (e.g., :custom)
      # @param handler_method [Symbol] The method name to handle this command
      # @example
      #   processor.register_inline_handler(:custom, :create_inline_custom_ast_node)
      def register_inline_handler(command, handler_method)
        @inline_handlers[command.to_sym] = handler_method
      end

      # @return [Array<Symbol>] List of all registered inline commands
      def registered_inline_commands
        @inline_handlers.keys
      end

      private

      # Create inline AST node from parsed token
      def create_inline_ast_node_from_token(token, parent_node)
        command = token.command.to_sym
        content = token.content

        # Look up handler method from dynamic registry
        handler_method = @inline_handlers[command]

        if handler_method
          # Call registered handler
          # ref_ast_node and cross_ref_ast_node need command as first argument (ref_type)
          # Others just need content and parent_node
          if handler_method == :create_inline_ref_ast_node || handler_method == :create_inline_cross_ref_ast_node
            send(handler_method, command, content, parent_node)
          else
            send(handler_method, content, parent_node)
          end
        else
          # Default handler for unknown inline commands
          create_standard_inline_node(command, content, parent_node)
        end
      end

      # Create standard inline node (default handler for unknown commands)
      def create_standard_inline_node(command, content, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: command,
          args: [content]
        )

        # Handle nested inline elements in the content
        if content.include?('@<')
          parse_inline_elements(content, inline_node)
        else
          # Simple text content
          text_node = AST::TextNode.new(
            location: @ast_compiler.location,
            content: content
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end

      # Create inline embed AST node
      def create_inline_embed_ast_node(arg, parent_node)
        target_builders, embed_content = RawContentParser.parse(arg)

        node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :inline,
          target_builders: target_builders,
          content: embed_content
        )
        parent_node.add_child(node)
      end

      # Create inline ruby AST node
      def create_inline_ruby_ast_node(arg, parent_node)
        # Parse ruby format: "base_text,ruby_text"
        if arg.include?(',')
          base_text, ruby_text = arg.split(',', 2)
          args = [base_text.strip, ruby_text.strip]

          inline_node = AST::InlineNode.new(
            location: @ast_compiler.location,
            inline_type: :ruby,
            args: args
          )

          # Add text nodes for both parts
          parent_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: base_text.strip
          )
          inline_node.add_child(parent_text)

          ruby_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: ruby_text.strip
          )
          inline_node.add_child(ruby_text)
        else
          inline_node = AST::InlineNode.new(
            location: @ast_compiler.location,
            inline_type: :ruby,
            args: [arg]
          )

          text_node = AST::TextNode.new(
            location: @ast_compiler.location,
            content: arg
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end

      # Create inline href AST node
      def create_inline_href_ast_node(arg, parent_node)
        # Parse href format: "URL" or "URL, display_text"
        args, text_content = if arg.include?(',')
                               parts = arg.split(',', 2)
                               [[parts[0].strip, parts[1].strip], parts[1].strip] # Display text
                             else
                               [[arg], arg] # URL as display text
                             end

        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: :href,
          args: args
        )

        text_node = AST::TextNode.new(
          location: @ast_compiler.location,
          content: text_content
        )
        inline_node.add_child(text_node)

        parent_node.add_child(inline_node)
      end

      # Create inline kw AST node
      def create_inline_kw_ast_node(arg, parent_node)
        # Parse kw format: "keyword" or "keyword, supplement"
        if arg.include?(',')
          parts = arg.split(',', 2)
          args = [parts[0].strip, parts[1].strip]

          inline_node = AST::InlineNode.new(
            location: @ast_compiler.location,
            inline_type: :kw,
            args: args
          )

          # Add text nodes for both parts
          main_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[0].strip
          )
          inline_node.add_child(main_text)

          supplement_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[1].strip
          )
          inline_node.add_child(supplement_text)
        else
          inline_node = AST::InlineNode.new(
            location: @ast_compiler.location,
            inline_type: :kw,
            args: [arg]
          )

          text_node = AST::TextNode.new(
            location: @ast_compiler.location,
            content: arg
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end

      # Create inline reference AST node (for img, list, table, eq, fn, endnote)
      def create_inline_ref_ast_node(ref_type, arg, parent_node)
        # Parse reference format: "ID" or "chapter_id|ID"
        if arg.include?('|')
          parts = arg.split('|', 2)
          chapter_id = parts[0].strip
          item_id = parts[1].strip
          reference_node = AST::ReferenceNode.new(item_id, chapter_id, location: @ast_compiler.location)
          args = [chapter_id, item_id]
        else
          chapter_id = nil
          item_id = arg
          reference_node = AST::ReferenceNode.new(item_id, nil, location: @ast_compiler.location)
          args = [arg]
        end

        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: ref_type,
          args: args,
          target_chapter_id: chapter_id,
          target_item_id: item_id
        )

        inline_node.add_child(reference_node)

        parent_node.add_child(inline_node)
      end

      # Create inline cross-reference AST node (for chap, chapref, sec, secref, sectitle, labelref, ref)
      def create_inline_cross_ref_ast_node(ref_type, arg, parent_node)
        # Handle special case for hd, sec, secref, and sectitle which support pipe-separated format
        if %i[hd sec secref sectitle].include?(ref_type.to_sym) && arg.include?('|')
          parts = arg.split('|', 2)
          chapter_id = parts[0].strip
          item_id = parts[1].strip
          reference_node = AST::ReferenceNode.new(item_id, chapter_id, location: @ast_compiler.location)
          args = [chapter_id, item_id]
        else
          # Standard cross-references with single ID argument
          chapter_id = nil
          item_id = arg
          reference_node = AST::ReferenceNode.new(item_id, nil, location: @ast_compiler.location)
          args = [arg]
        end

        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: ref_type,
          args: args,
          target_chapter_id: chapter_id,
          target_item_id: item_id
        )

        inline_node.add_child(reference_node)

        parent_node.add_child(inline_node)
      end

      # Create inline raw AST node (@<raw> command)
      def create_inline_raw_ast_node(content, parent_node)
        target_builders, processed_content = RawContentParser.parse(content)

        embed_node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :inline,
          target_builders: target_builders,
          content: processed_content
        )

        parent_node.add_child(embed_node)
      end
    end
  end
end
