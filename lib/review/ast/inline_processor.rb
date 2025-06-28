# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'

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
      end

      # Parse inline elements and create AST nodes
      def parse_inline_elements(str, parent_node)
        return if str.empty?

        # Parse both fence syntax (@<cmd>$...$, @<cmd>|...|) and brace syntax (@<cmd>{...})
        tokens = tokenize_inline_elements(str)

        tokens.each do |token|
          if token[:type] == :inline
            create_inline_ast_node_from_token(token, parent_node)
          else
            # Plain text
            unless token[:content].empty?
              text_node = AST::TextNode.new(
                location: @ast_compiler.location,
                content: token[:content]
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
        command = token[:command]
        content = token[:content]

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

      private

      # Tokenize string into inline elements and text parts
      def tokenize_inline_elements(str)
        tokens = []
        pos = 0

        while pos < str.length
          # Look for inline element pattern
          match = str.match(/@<(\w+)>([{$|])/, pos)

          if match
            # Add text before the match as plain text token
            if match.begin(0) > pos
              text_content = str[pos...match.begin(0)]
              tokens << { type: :text, content: text_content } unless text_content.empty?
            end

            # Parse the inline element
            inline_token = parse_inline_element_at(str, match.begin(0))
            if inline_token
              tokens << inline_token
              pos = inline_token[:end_pos]
            else
              # Failed to parse as inline element, treat as text
              tokens << { type: :text, content: match[0] }
              pos = match.end(0)
            end
          else
            # No more inline elements, add remaining text
            remaining_text = str[pos..-1]
            tokens << { type: :text, content: remaining_text } unless remaining_text.empty?
            break
          end
        end

        tokens
      end

      # Parse inline element at specific position
      def parse_inline_element_at(str, start_pos)
        # Match @<command> part from the specified position
        substring = str[start_pos..-1]
        command_match = substring.match(/\A@<(\w+)>([{$|])/)
        return nil unless command_match

        command = command_match[1]
        delimiter = command_match[2]
        content_start = start_pos + command_match[0].length

        # Find matching closing delimiter
        case delimiter
        when '{'
          content, end_pos = parse_brace_content(str, content_start)
        when '$', '|'
          content, end_pos = parse_fence_content(str, content_start, delimiter)
        else
          return nil
        end

        return nil unless content && end_pos

        {
          type: :inline,
          command: command,
          content: content,
          start_pos: start_pos,
          end_pos: end_pos
        }
      end

      # Parse content within braces, handling escaped braces
      def parse_brace_content(str, start_pos)
        content = ''
        pos = start_pos
        brace_count = 1

        while pos < str.length && brace_count > 0
          char = str[pos]

          case char
          when '\\'
            # Handle escaped character
            if pos + 1 < str.length
              content += char + str[pos + 1]
              pos += 2
            else
              content += char
              pos += 1
            end
          when '{'
            brace_count += 1
            content += char
            pos += 1
          when '}'
            brace_count -= 1
            if brace_count > 0
              content += char
            end
            pos += 1
          else
            content += char
            pos += 1
          end
        end

        # Return content and end position if properly closed
        brace_count == 0 ? [content, pos] : [nil, nil]
      end

      # Parse content within fence delimiters
      def parse_fence_content(str, start_pos, delimiter)
        end_pos = str.index(delimiter, start_pos)
        return [nil, nil] unless end_pos

        content = str[start_pos...end_pos]
        [content, end_pos + 1]
      end
    end
  end
end
