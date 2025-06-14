# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/ast'

module ReVIEW
  class JSONBuilder < Builder
    def initialize(strict = false, *args, **kwargs)
      super
      @document_node = nil
      @current_node = nil
      @node_stack = []
    end

    def bind(compiler, chapter, location)
      super
      @document_node = AST::DocumentNode.new(location)
      @document_node.title = chapter.title if chapter.respond_to?(:title)
      @current_node = @document_node
    end

    def result
      # In AST mode, check if compiler has provided an AST result
      if @compiler.respond_to?(:ast_result) && @compiler.ast_result
        # Use the AST from the compiler
        require 'review/ast/json_serializer'
        options = ReVIEW::AST::JSONSerializer::Options.new
        options.include_empty_arrays = true
        ReVIEW::AST::JSONSerializer.serialize(@compiler.ast_result, options)
      else
        # Use our internal document node
        JSON.pretty_generate(@document_node.to_h)
      end
    end

    # Special method to add an AST node directly (used by compiler in AST mode)
    def add_ast_node(ast_node)
      @document_node.add_child(ast_node)
    end

    def headline(level, label, caption)
      node = AST::HeadlineNode.new(@location)
      node.level = level
      node.label = label
      node.caption = caption
      add_node(node)
    end

    def paragraph(lines)
      node = AST::ParagraphNode.new(@location)
      # Create TextNode for paragraph content to maintain consistency with AST mode
      content = lines.join("\n")
      if !content.empty?
        text_node = AST::TextNode.new(@location)
        text_node.content = content
        node.add_child(text_node)
      end
      add_node(node)
    end

    def list(lines, id, caption, lang = nil)
      node = AST::CodeBlockNode.new(@location)
      node.lang = lang
      node.id = id
      node.caption = caption
      node.lines = lines
      node.line_numbers = false
      add_node(node)
    end

    def listnum(lines, id, caption, lang = nil)
      node = AST::CodeBlockNode.new(@location)
      node.lang = lang
      node.id = id
      node.caption = caption
      node.lines = lines
      node.line_numbers = true
      add_node(node)
    end

    def emlist(lines, caption = nil, lang = nil)
      node = AST::CodeBlockNode.new(@location)
      node.lang = lang
      node.caption = caption
      node.lines = lines
      node.line_numbers = false
      add_node(node)
    end

    def emlistnum(lines, caption = nil, lang = nil)
      node = AST::CodeBlockNode.new(@location)
      node.lang = lang
      node.caption = caption
      node.lines = lines
      node.line_numbers = true
      add_node(node)
    end

    def cmd(lines, caption = nil)
      node = AST::CodeBlockNode.new(@location)
      node.lang = 'shell'
      node.caption = caption
      node.lines = lines
      node.line_numbers = false
      add_node(node)
    end

    def source(lines, caption = nil, lang = nil)
      node = AST::CodeBlockNode.new(@location)
      node.lang = lang
      node.caption = caption
      node.lines = lines
      node.line_numbers = false
      add_node(node)
    end

    def image(_lines, id, caption, metric = nil)
      node = AST::ImageNode.new(@location)
      node.id = id
      node.caption = caption
      node.metric = metric
      add_node(node)
    end

    def indepimage(lines, id, caption, metric = nil)
      image(lines, id, caption, metric)
    end

    def numberlessimage(lines, id, caption, metric = nil)
      image(lines, id, caption, metric)
    end

    def table(lines, id = nil, caption = nil)
      sepidx, rows = parse_table_rows(lines)
      node = AST::TableNode.new(@location)
      node.id = id
      node.caption = caption

      if sepidx
        node.headers = rows[0...sepidx]
        node.rows = rows[sepidx..-1]
      else
        node.headers = []
        node.rows = rows
      end

      add_node(node)
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def ul_begin(&_block)
      node = AST::ListNode.new(@location)
      node.list_type = :ul
      push_node(node)
    end

    def ul_item_begin(lines)
      item_node = AST::ListItemNode.new(@location)
      item_node.content = lines.join("\n")
      @current_node.items << item_node
    end

    def ul_item_end
      # no-op
    end

    def ul_end(&_block)
      pop_node
    end

    def ol_begin
      node = AST::ListNode.new(@location)
      node.list_type = :ol
      push_node(node)
    end

    def ol_item(lines, num)
      item_node = AST::ListItemNode.new(@location)
      item_node.content = lines.join("\n")
      item_node.level = num.to_i
      @current_node.items << item_node
    end

    def ol_end
      pop_node
    end

    def dl_begin
      node = AST::ListNode.new(@location)
      node.list_type = :dl
      push_node(node)
    end

    def dt(str)
      item_node = AST::ListItemNode.new(@location)
      item_node.content = str
      @current_node.items << item_node
    end

    def dd(lines)
      # Associate dd with the previous dt by adding to the last item
      if @current_node.items.last
        @current_node.items.last.children << AST::ParagraphNode.new(@location).tap do |para|
          para.content = lines.join("\n")
        end
      end
    end

    def dl_end
      pop_node
    end

    # Inline element processing
    def compile_inline(str)
      # Currently returns as-is (detailed implementation planned for Phase 2)
      str
    end

    def nofunc_text(str)
      str
    end

    # Inline element methods needed for AST processing
    def inline_hd(str)
      create_inline_node('hd', str)
    end

    def inline_hd_chap(str)
      create_inline_node('hd', str)
    end

    def inline_img(str)
      create_inline_node('img', str)
    end

    def inline_list(str)
      create_inline_node('list', str)
    end

    def inline_table(str)
      create_inline_node('table', str)
    end

    def inline_eq(str)
      create_inline_node('eq', str)
    end

    def inline_chap(str)
      create_inline_node('chap', str)
    end

    def inline_chapref(str)
      create_inline_node('chapref', str)
    end

    def inline_sec(str)
      create_inline_node('sec', str)
    end

    def inline_secref(str)
      create_inline_node('secref', str)
    end

    def inline_labelref(str)
      create_inline_node('labelref', str)
    end

    def inline_ref(str)
      create_inline_node('ref', str)
    end

    def inline_w(str)
      create_inline_node('w', str)
    end

    def inline_wb(str)
      create_inline_node('wb', str)
    end

    def inline_b(str)
      create_inline_node('b', str)
    end

    def inline_i(str)
      create_inline_node('i', str)
    end

    def inline_code(str)
      create_inline_node('code', str)
    end

    def inline_tt(str)
      create_inline_node('tt', str)
    end

    def inline_ruby(str)
      create_inline_node('ruby', str)
    end

    def inline_href(str)
      create_inline_node('href', str)
    end

    def inline_kw(str)
      create_inline_node('kw', str)
    end

    def inline_embed(str)
      create_inline_node('embed', str)
    end

    def embed(lines, arg = nil)
      node = AST::EmbedNode.new(@location)
      node.embed_type = :block
      node.lines = lines
      node.arg = arg
      add_node(node)
    end

    def raw(arg)
      # Raw commands are processed traditionally and don't create AST nodes
      # This is just a compatibility method for JsonBuilder
    end

    def quote(lines)
      node = AST::ParagraphNode.new(@location)
      node.content = lines.join("\n")
      add_node(node)
    end

    # Block commands that were missing
    def lead(lines)
      node = AST::Node.new(@location)
      node.type = 'lead'
      lines.each do |line|
        text_node = AST::TextNode.new(@location)
        text_node.content = line
        node.add_child(text_node)
      end
      @current_node.add_child(node)
    end

    def noindent
      # No-op for JSON output
    end

    def footnote(id, str)
      node = AST::Node.new(@location)
      node.type = 'footnote'
      node.id = id
      node.content = str
      @current_node.add_child(node)
    end

    def olnum(num)
      # Store the starting number for ordered lists
      # This is typically used to set the starting number for the next ol_item
      @ol_num = num.to_i
    end

    # Inline commands that were missing
    def inline_br(_str)
      # For now, return empty string as builders expect string output
      # In AST mode, this would be handled differently
      ''
    end

    # Section types that were missing
    def nonum_begin(level, label, caption)
      node = AST::HeadlineNode.new(@location)
      node.level = level
      node.label = label
      node.caption = caption
      node.type = 'nonum'
      @current_node.add_child(node)
    end

    def nonum_end(level)
      # No-op for JSON
    end

    def nodisp_begin(level, label, caption)
      node = AST::HeadlineNode.new(@location)
      node.level = level
      node.label = label
      node.caption = caption
      node.type = 'nodisp'
      @current_node.add_child(node)
    end

    def nodisp_end(level)
      # No-op for JSON
    end

    private

    def create_inline_node(_inline_type, content)
      # For JsonBuilder, we return the processed string content
      # The AST nodes are created by the compiler, not by the builder
      content
    end

    # Dummy implementations for other Builder methods
    def note(lines, caption = nil)
      captionblock('note', lines, caption)
    end

    def memo(lines, caption = nil)
      captionblock('memo', lines, caption)
    end

    def tip(lines, caption = nil)
      captionblock('tip', lines, caption)
    end

    def info(lines, caption = nil)
      captionblock('info', lines, caption)
    end

    def warning(lines, caption = nil)
      captionblock('warning', lines, caption)
    end

    def important(lines, caption = nil)
      captionblock('important', lines, caption)
    end

    def caution(lines, caption = nil)
      captionblock('caution', lines, caption)
    end

    def notice(lines, caption = nil)
      captionblock('notice', lines, caption)
    end

    def captionblock(_type, lines, _caption, _specialstyle = nil)
      node = AST::ParagraphNode.new(@location)
      node.content = lines.join("\n")
      # Also preserves type and caption information (dedicated node types planned for future)
      add_node(node)
    end

    # Minicolumn begin/end methods
    def note_begin(caption = nil)
      # no-op for JSON builder
    end

    def note_end
      # no-op for JSON builder
    end

    def memo_begin(caption = nil)
      # no-op for JSON builder
    end

    def memo_end
      # no-op for JSON builder
    end

    def tip_begin(caption = nil)
      # no-op for JSON builder
    end

    def tip_end
      # no-op for JSON builder
    end

    def info_begin(caption = nil)
      # no-op for JSON builder
    end

    def info_end
      # no-op for JSON builder
    end

    def warning_begin(caption = nil)
      # no-op for JSON builder
    end

    def warning_end
      # no-op for JSON builder
    end

    def important_begin(caption = nil)
      # no-op for JSON builder
    end

    def important_end
      # no-op for JSON builder
    end

    def caution_begin(caption = nil)
      # no-op for JSON builder
    end

    def caution_end
      # no-op for JSON builder
    end

    def notice_begin(caption = nil)
      # no-op for JSON builder
    end

    def notice_end
      # no-op for JSON builder
    end

    # Other methods that may be needed
    def blockquote(lines)
      quote(lines)
    end

    def add_node(node)
      @current_node.add_child(node)
    end

    def push_node(node)
      @current_node.add_child(node)
      @node_stack.push(@current_node)
      @current_node = node
    end

    def pop_node
      @current_node = @node_stack.pop if @node_stack.any?
    end
  end
end
