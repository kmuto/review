# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require_relative 'inline_tokenizer'

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
      def initialize(ast_compiler)
        @ast_compiler = ast_compiler
        @tokenizer = InlineTokenizer.new
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

      # Create inline embed AST node
      def create_inline_embed_ast_node(arg, parent_node)
        node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :inline,
          lines: [arg],
          arg: arg
        )
        parent_node.add_child(node)
      end

      # Create inline ruby AST node
      def create_inline_ruby_ast_node(arg, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: 'ruby'
        )

        # Parse ruby format: "base_text,ruby_text"
        if arg.include?(',')
          parts = arg.split(',', 2)
          inline_node.args = [parts[0].strip, parts[1].strip]

          # Add text nodes for both parts
          parent_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[0].strip
          )
          inline_node.add_child(parent_text)

          ruby_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[1].strip
          )
          inline_node.add_child(ruby_text)
        else
          inline_node.args = [arg]
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
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: 'href'
        )

        # Parse href format: "URL" or "URL, display_text"
        text_content = if arg.include?(',')
                         parts = arg.split(',', 2)
                         inline_node.args = [parts[0].strip, parts[1].strip]
                         parts[1].strip # Display text
                       else
                         inline_node.args = [arg]
                         arg # URL as display text
                       end

        text_node = AST::TextNode.new(
          location: @ast_compiler.location,
          content: text_content
        )
        inline_node.add_child(text_node)

        parent_node.add_child(inline_node)
      end

      # Create inline kw AST node
      def create_inline_kw_ast_node(arg, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: 'kw'
        )

        # Parse kw format: "keyword" or "keyword, supplement"
        if arg.include?(',')
          parts = arg.split(',', 2)
          inline_node.args = [parts[0].strip, parts[1].strip]

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
          inline_node.args = [arg]
          text_node = AST::TextNode.new(
            location: @ast_compiler.location,
            content: arg
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end

      # Create inline hd AST node
      def create_inline_hd_ast_node(arg, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: 'hd'
        )

        # Parse hd format: "chapter_id|heading" or just "heading"
        if arg.include?('|')
          parts = arg.split('|', 2)
          inline_node.args = [parts[0].strip, parts[1].strip]

          # Add text nodes for both parts
          chapter_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[0].strip
          )
          inline_node.add_child(chapter_text)

          heading_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[1].strip
          )
          inline_node.add_child(heading_text)
        else
          inline_node.args = [arg]
          text_node = AST::TextNode.new(
            location: @ast_compiler.location,
            content: arg
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end

      # Create inline reference AST node (for img, list, table, eq)
      def create_inline_ref_ast_node(ref_type, arg, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: ref_type
        )

        # Parse reference format: "ID" or "chapter_id|ID"
        if arg.include?('|')
          parts = arg.split('|', 2)
          inline_node.args = [parts[0].strip, parts[1].strip]

          # Add text nodes for both parts
          chapter_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[0].strip
          )
          inline_node.add_child(chapter_text)

          id_text = AST::TextNode.new(
            location: @ast_compiler.location,
            content: parts[1].strip
          )
          inline_node.add_child(id_text)
        else
          inline_node.args = [arg]
          text_node = AST::TextNode.new(
            location: @ast_compiler.location,
            content: arg
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end

      # Create inline cross-reference AST node (for chap, chapref, sec, secref, labelref, ref)
      def create_inline_cross_ref_ast_node(ref_type, arg, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: ref_type
        )

        # Cross-references typically just have a single ID argument
        inline_node.args = [arg]
        text_node = AST::TextNode.new(
          location: @ast_compiler.location,
          content: arg
        )
        inline_node.add_child(text_node)

        parent_node.add_child(inline_node)
      end

      # Create inline word AST node (for w, wb)
      def create_inline_word_ast_node(word_type, arg, parent_node)
        inline_node = AST::InlineNode.new(
          location: @ast_compiler.location,
          inline_type: word_type
        )

        # Word expansion commands just have the filename argument
        inline_node.args = [arg]
        text_node = AST::TextNode.new(
          location: @ast_compiler.location,
          content: arg
        )
        inline_node.add_child(text_node)

        parent_node.add_child(inline_node)
      end

      # Create inline AST node from parsed token
      def create_inline_ast_node_from_token(token, parent_node)
        command = token.command
        content = token.content

        # Special handling for certain inline types
        case command
        when 'embed'
          create_inline_embed_ast_node(content, parent_node)
        when 'ruby'
          create_inline_ruby_ast_node(content, parent_node)
        when 'href'
          create_inline_href_ast_node(content, parent_node)
        when 'kw'
          create_inline_kw_ast_node(content, parent_node)
        when 'hd'
          create_inline_hd_ast_node(content, parent_node)
        when 'img', 'list', 'table', 'eq'
          create_inline_ref_ast_node(command, content, parent_node)
        when 'chap', 'chapref', 'sec', 'secref', 'labelref', 'ref'
          create_inline_cross_ref_ast_node(command, content, parent_node)
        when 'w', 'wb'
          create_inline_word_ast_node(command, content, parent_node)
        when 'raw'
          create_inline_raw_ast_node(content, parent_node)
        else
          # Standard inline processing
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
      end

      # Create inline raw AST node (@<raw> command)
      def create_inline_raw_ast_node(content, parent_node)
        target_builders, processed_content = parse_raw_content(content)

        embed_node = AST::EmbedNode.new(
          location: @ast_compiler.location,
          embed_type: :inline,
          arg: content,
          target_builders: target_builders,
          content: processed_content
        )

        parent_node.add_child(embed_node)
      end

      private

      # Parse raw content for builder specification (shared with BlockProcessor)
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
    end
  end
end
