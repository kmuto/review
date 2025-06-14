# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'

module ReVIEW
  # InlineASTProcessor - Inline element parsing and AST node creation
  #
  # This class handles the complex parsing of Re:VIEW inline elements
  # and converts them to appropriate AST nodes with proper nesting.
  #
  # Responsibilities:
  # - Parse inline markup (@<command>{content}) within text
  # - Create appropriate AST nodes for different inline types
  # - Handle nested inline elements
  # - Process specialized inline formats (ruby, href, kw, etc.)
  class InlineASTProcessor
    def initialize(ast_compiler)
      @ast_compiler = ast_compiler
    end

    # Parse inline elements and create AST nodes
    def parse_inline_elements(str, parent_node)
      return if str.empty?

      words = replace_fence(str).split(/(@<\w+>\{(?:[^}\\]|\\.)*?\})/, -1)
      words.each do |word|
        if word.match?(/\A@<\w+>\{.*?\}\z/)
          # This is an inline element
          create_inline_ast_node(word, parent_node)
        else
          # This is plain text
          unless word.empty?
            text_node = AST::TextNode.new(@ast_compiler.location)
            text_node.content = revert_replace_fence(word)
            parent_node.add_child(text_node)
          end
        end
      end
    end

    # Create inline AST node
    def create_inline_ast_node(str, parent_node)
      match = /\A@<(\w+)>\{(.*?)\}\z/.match(revert_replace_fence(str.gsub('\\}', '}').gsub('\\\\', '\\')))
      return unless match

      op = match[1]
      arg = match[2]

      # Special handling for certain inline types
      case op
      when 'embed'
        create_inline_embed_ast_node(arg, parent_node)
      when 'ruby'
        create_inline_ruby_ast_node(arg, parent_node)
      when 'href'
        create_inline_href_ast_node(arg, parent_node)
      when 'kw'
        create_inline_kw_ast_node(arg, parent_node)
      when 'hd'
        create_inline_hd_ast_node(arg, parent_node)
      when 'img', 'list', 'table', 'eq'
        create_inline_ref_ast_node(op, arg, parent_node)
      when 'chap', 'chapref', 'sec', 'secref', 'labelref', 'ref'
        create_inline_cross_ref_ast_node(op, arg, parent_node)
      when 'w', 'wb'
        create_inline_word_ast_node(op, arg, parent_node)
      else
        # Standard inline processing
        inline_node = AST::InlineNode.new(@ast_compiler.location)
        inline_node.inline_type = op
        inline_node.args = [arg]

        # Handle nested inline elements in the argument
        if arg.include?('@<')
          parse_inline_elements(arg, inline_node)
        else
          # Simple text argument
          text_node = AST::TextNode.new(@ast_compiler.location)
          text_node.content = arg
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end
    end

    # Create inline embed AST node
    def create_inline_embed_ast_node(arg, parent_node)
      node = AST::EmbedNode.new(@ast_compiler.location)
      node.embed_type = :inline
      node.lines = [arg]
      node.arg = arg
      parent_node.add_child(node)
    end

    # Create inline ruby AST node
    def create_inline_ruby_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = 'ruby'

      # Parse ruby format: "base_text,ruby_text"
      if arg.include?(',')
        parts = arg.split(',', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        parent_text = AST::TextNode.new(@ast_compiler.location)
        parent_text.content = parts[0].strip
        inline_node.add_child(parent_text)

        ruby_text = AST::TextNode.new(@ast_compiler.location)
        ruby_text.content = parts[1].strip
        inline_node.add_child(ruby_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(@ast_compiler.location)
        text_node.content = arg
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline href AST node
    def create_inline_href_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = 'href'

      # Parse href format: "URL" or "URL, display_text"
      text_content = if arg.include?(',')
                       parts = arg.split(',', 2)
                       inline_node.args = [parts[0].strip, parts[1].strip]
                       parts[1].strip # Display text
                     else
                       inline_node.args = [arg]
                       arg # URL as display text
                     end

      text_node = AST::TextNode.new(@ast_compiler.location)
      text_node.content = text_content
      inline_node.add_child(text_node)

      parent_node.add_child(inline_node)
    end

    # Create inline kw AST node
    def create_inline_kw_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = 'kw'

      # Parse kw format: "keyword" or "keyword, supplement"
      if arg.include?(',')
        parts = arg.split(',', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        main_text = AST::TextNode.new(@ast_compiler.location)
        main_text.content = parts[0].strip
        inline_node.add_child(main_text)

        supplement_text = AST::TextNode.new(@ast_compiler.location)
        supplement_text.content = parts[1].strip
        inline_node.add_child(supplement_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(@ast_compiler.location)
        text_node.content = arg
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline hd AST node
    def create_inline_hd_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = 'hd'

      # Parse hd format: "chapter_id|heading" or just "heading"
      if arg.include?('|')
        parts = arg.split('|', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        chapter_text = AST::TextNode.new(@ast_compiler.location)
        chapter_text.content = parts[0].strip
        inline_node.add_child(chapter_text)

        heading_text = AST::TextNode.new(@ast_compiler.location)
        heading_text.content = parts[1].strip
        inline_node.add_child(heading_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(@ast_compiler.location)
        text_node.content = arg
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline reference AST node (for img, list, table, eq)
    def create_inline_ref_ast_node(ref_type, arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = ref_type

      # Parse reference format: "ID" or "chapter_id|ID"
      if arg.include?('|')
        parts = arg.split('|', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        chapter_text = AST::TextNode.new(@ast_compiler.location)
        chapter_text.content = parts[0].strip
        inline_node.add_child(chapter_text)

        id_text = AST::TextNode.new(@ast_compiler.location)
        id_text.content = parts[1].strip
        inline_node.add_child(id_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(@ast_compiler.location)
        text_node.content = arg
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline cross-reference AST node (for chap, chapref, sec, secref, labelref, ref)
    def create_inline_cross_ref_ast_node(ref_type, arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = ref_type

      # Cross-references typically just have a single ID argument
      inline_node.args = [arg]
      text_node = AST::TextNode.new(@ast_compiler.location)
      text_node.content = arg
      inline_node.add_child(text_node)

      parent_node.add_child(inline_node)
    end

    # Create inline word AST node (for w, wb)
    def create_inline_word_ast_node(word_type, arg, parent_node)
      inline_node = AST::InlineNode.new(@ast_compiler.location)
      inline_node.inline_type = word_type

      # Word expansion commands just have the filename argument
      inline_node.args = [arg]
      text_node = AST::TextNode.new(@ast_compiler.location)
      text_node.content = arg
      inline_node.add_child(text_node)

      parent_node.add_child(inline_node)
    end

    private

    def replace_fence(str)
      str.gsub(/@<(\w+)>([$|])(.+?)(\2)/) do
        op = $1
        arg = $3
        if /[\x01\x02\x03\x04]/.match?(arg)
          # Handle error - would need access to error reporting
          next "@<#{op}>{#{arg}}"
        end

        replaced = arg.tr('@', "\x01").tr('\\', "\x02").tr('{', "\x03").tr('}', "\x04")
        "@<#{op}>{#{replaced}}"
      end
    end

    def revert_replace_fence(str)
      str.tr("\x01", '@').tr("\x02", '\\').tr("\x03", '{').tr("\x04", '}')
    end
  end
end
