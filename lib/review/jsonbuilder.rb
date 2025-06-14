# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/ast'
require 'review/ast/column_node'

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
      title = chapter.respond_to?(:title) ? chapter.title : nil
      @document_node = AST::DocumentNode.new(location: location, title: title)
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
      node = AST::HeadlineNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption)
      )
      add_node(node)
    end

    def paragraph(lines)
      node = AST::ParagraphNode.new(location: location)
      # Create TextNode for paragraph content to maintain consistency with AST mode
      content = lines.join("\n")
      unless content.empty?
        text_node = AST::TextNode.new(location: location, content: content)
        node.add_child(text_node)
      end
      add_node(node)
    end

    def list(lines, id, caption, lang = nil)
      node = AST::CodeBlockNode.new(
        location: location,
        lang: lang,
        id: id,
        caption: parse_caption(caption),
        lines: lines,
        line_numbers: false
      )
      add_node(node)
    end

    def listnum(lines, id, caption, lang = nil)
      node = AST::CodeBlockNode.new(
        location: location,
        lang: lang,
        id: id,
        caption: parse_caption(caption),
        lines: lines,
        line_numbers: true
      )
      add_node(node)
    end

    def emlist(lines, caption = nil, lang = nil)
      node = AST::CodeBlockNode.new(
        location: location,
        lang: lang,
        caption: parse_caption(caption),
        lines: lines,
        line_numbers: false
      )
      add_node(node)
    end

    def emlistnum(lines, caption = nil, lang = nil)
      node = AST::CodeBlockNode.new(
        location: location,
        lang: lang,
        caption: parse_caption(caption),
        lines: lines,
        line_numbers: true
      )
      add_node(node)
    end

    def cmd(lines, caption = nil)
      node = AST::CodeBlockNode.new(
        location: location,
        lang: 'shell',
        caption: parse_caption(caption),
        lines: lines,
        line_numbers: false
      )
      add_node(node)
    end

    def source(lines, caption = nil, lang = nil)
      node = AST::CodeBlockNode.new(
        location: location,
        lang: lang,
        caption: parse_caption(caption),
        lines: lines,
        line_numbers: false
      )
      add_node(node)
    end

    def image(_lines, id, caption = nil, metric = nil)
      node = AST::ImageNode.new(
        location: location,
        id: id,
        caption: parse_caption(caption),
        metric: metric
      )
      add_node(node)
    end

    def indepimage(lines, id, caption = nil, metric = nil)
      image(lines, id, caption, metric)
    end

    def numberlessimage(lines, id, caption = nil, metric = nil)
      image(lines, id, caption, metric)
    end

    def table(lines = nil, id = nil, caption = nil)
      # Handle case where lines is nil or empty
      if lines.nil? || lines.empty?
        node = AST::TableNode.new(
          location: location,
          id: id,
          caption: parse_caption(caption),
          headers: [],
          rows: []
        )
        add_node(node)
        return
      end

      sepidx, rows = parse_table_rows(lines)

      if sepidx
        headers = rows[0...sepidx]
        table_rows = rows[sepidx..-1]
      else
        headers = []
        table_rows = rows
      end

      node = AST::TableNode.new(
        location: location,
        id: id,
        caption: parse_caption(caption),
        headers: headers,
        rows: table_rows
      )

      add_node(node)
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def ul_begin(&_block)
      node = AST::ListNode.new(
        location: location,
        list_type: :ul
      )
      push_node(node)
    end

    def ul_item_begin(lines)
      item_node = AST::ListItemNode.new(
        location: location,
        content: lines.join("\n")
      )
      @current_node.items << item_node
    end

    def ul_item_end
      # no-op
    end

    def ul_end(&_block)
      pop_node
    end

    def ol_begin
      node = AST::ListNode.new(
        location: location,
        list_type: :ol
      )
      push_node(node)
    end

    def ol_item(lines, num)
      item_node = AST::ListItemNode.new(
        location: location,
        content: lines.join("\n"),
        level: num.to_i
      )
      @current_node.items << item_node
    end

    def ol_end
      pop_node
    end

    def dl_begin
      node = AST::ListNode.new(
        location: location,
        list_type: :dl
      )
      push_node(node)
    end

    def dt(str)
      item_node = AST::ListItemNode.new(
        location: location,
        content: str
      )
      @current_node.items << item_node
    end

    def dd(lines)
      # Associate dd with the previous dt by adding to the last item
      if @current_node.items.last
        @current_node.items.last.children << AST::ParagraphNode.new(location: location).tap do |para|
          para.content = lines.join("\n")
        end
      end
    end

    def dl_end
      pop_node
    end

    # Inline element processing
    def compile_inline(str)
      # For traditional mode, return unprocessed inline content
      # For AST processing, use compile_inline_ast helper method
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
      node = AST::EmbedNode.new(
        location: location,
        embed_type: :block,
        lines: lines,
        arg: arg
      )
      add_node(node)
    end

    def raw(arg)
      # Raw commands are processed traditionally and don't create AST nodes
      # This is just a compatibility method for JsonBuilder
    end

    def quote(lines)
      node = AST::ParagraphNode.new(
        location: location,
        content: lines.join("\n")
      )
      add_node(node)
    end

    # Block commands that were missing
    def lead(lines)
      node = AST::Node.new(
        location: location,
        type: 'lead'
      )
      lines.each do |line|
        text_node = AST::TextNode.new(
          location: location,
          content: line
        )
        node.add_child(text_node)
      end
      @current_node.add_child(node)
    end

    def noindent
      # No-op for JSON output
    end

    def pagebreak
      # Create a node to represent the page break
      node = AST::Node.new(location: location, type: 'pagebreak')
      add_node(node)
    end

    def footnote(id, str)
      node = AST::Node.new(
        location: location,
        type: 'footnote',
        id: id,
        content: str
      )
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
      node = AST::HeadlineNode.new(
        location: location,
        level: level,
        label: label,
        caption: caption,
        type: 'nonum'
      )
      @current_node.add_child(node)
    end

    def nonum_end(level)
      # No-op for JSON
    end

    def nodisp_begin(level, label, caption)
      node = AST::HeadlineNode.new(
        location: location,
        level: level,
        label: label,
        caption: caption,
        type: 'nodisp'
      )
      @current_node.add_child(node)
    end

    def nodisp_end(level)
      # No-op for JSON
    end

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
      node = AST::ParagraphNode.new(
        location: location,
        content: lines.join("\n")
      )
      # Also preserves type and caption information (dedicated node types planned for future)
      add_node(node)
    end

    # Minicolumn begin/end methods
    def note_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'note'
      node = AST::Node.new(
        location: location,
        type: 'note',
        content: caption
      )
      push_node(node)
    end

    def note_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def memo_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'memo'
      node = AST::Node.new(
        location: location,
        type: 'memo',
        content: caption
      )
      push_node(node)
    end

    def memo_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def tip_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'tip'
      node = AST::Node.new(
        location: location,
        type: 'tip',
        content: caption
      )
      push_node(node)
    end

    def tip_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def info_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'info'
      node = AST::Node.new(
        location: location,
        type: 'info',
        content: caption
      )
      push_node(node)
    end

    def info_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def warning_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'warning'
      node = AST::Node.new(
        location: location,
        type: 'warning',
        content: caption
      )
      push_node(node)
    end

    def warning_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def important_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'important'
      node = AST::Node.new(
        location: location,
        type: 'important',
        content: caption
      )
      push_node(node)
    end

    def important_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def caution_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'caution'
      node = AST::Node.new(
        location: location,
        type: 'caution',
        content: caption
      )
      push_node(node)
    end

    def caution_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    def notice_begin(caption = nil)
      check_nested_minicolumn
      @doc_status[:minicolumn] = 'notice'
      node = AST::Node.new(
        location: location,
        type: 'notice',
        content: caption
      )
      push_node(node)
    end

    def notice_end
      @doc_status[:minicolumn] = nil
      pop_node
    end

    # Other methods that may be needed
    def blockquote(lines)
      quote(lines)
    end

    def add_node(node)
      @current_node.add_child(node)
    end

    # Additional block commands
    def imgtable(_lines, id = nil, caption = nil, metric = nil)
      # For JSON, treat as image with table type
      node = AST::ImageNode.new(
        location: location,
        id: id,
        caption: caption,
        metric: metric
      )
      add_node(node)
    end

    def flushright(lines)
      # For JSON, treat as generic node
      node = AST::Node.new(
        location: location,
        type: 'flushright'
      )
      lines.each do |line|
        text_node = AST::TextNode.new(
          location: location,
          content: line
        )
        node.add_child(text_node)
      end
      add_node(node)
    end

    def texequation(lines, id = nil, caption = nil)
      # For JSON, create a generic node for TeX equations
      node = AST::Node.new(
        location: location,
        type: 'texequation',
        id: id
      )
      node.content = caption if caption
      lines&.each do |line|
        text_node = AST::TextNode.new(
          location: location,
          content: line
        )
        node.add_child(text_node)
      end
      add_node(node)
    end

    def label(id)
      # For JSON, create a generic node for labels
      node = AST::Node.new(
        location: location,
        type: 'label',
        id: id
      )
      add_node(node)
    end

    def push_node(node)
      @current_node.add_child(node)
      @node_stack.push(@current_node)
      @current_node = node
    end

    def pop_node
      @current_node = @node_stack.pop if @node_stack.any?
    end

    # Tagged section support
    def column_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'column'
      )
      push_node(node)
    end

    def column_end(_level)
      pop_node
    end

    def xcolumn_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'xcolumn'
      )
      push_node(node)
    end

    def xcolumn_end(_level)
      pop_node
    end

    # Support for other column types that may exist
    def world_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'world'
      )
      push_node(node)
    end

    def world_end(_level)
      pop_node
    end

    def hood_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'hood'
      )
      push_node(node)
    end

    def hood_end(_level)
      pop_node
    end

    def edition_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'edition'
      )
      push_node(node)
    end

    def edition_end(_level)
      pop_node
    end

    def insideout_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'insideout'
      )
      push_node(node)
    end

    def insideout_end(_level)
      pop_node
    end

    def notoc_begin(level, label, caption)
      node = AST::ColumnNode.new(
        location: location,
        level: level,
        label: label,
        caption: parse_caption(caption),
        column_type: 'notoc'
      )
      push_node(node)
    end

    def notoc_end(_level)
      pop_node
    end

    # Additional inline methods
    def inline_m(str)
      create_inline_node('m', str)
    end

    def inline_strong(str)
      create_inline_node('strong', str)
    end

    def inline_em(str)
      create_inline_node('em', str)
    end

    def inline_u(str)
      create_inline_node('u', str)
    end

    def inline_ttb(str)
      create_inline_node('ttb', str)
    end

    def inline_tti(str)
      create_inline_node('tti', str)
    end

    def inline_ami(str)
      create_inline_node('ami', str)
    end

    def inline_ins(str)
      create_inline_node('ins', str)
    end

    def inline_del(str)
      create_inline_node('del', str)
    end

    def inline_uchar(str)
      create_inline_node('uchar', str)
    end

    def inline_icon(str)
      create_inline_node('icon', str)
    end

    def inline_bib(str)
      create_inline_node('bib', str)
    end

    def inline_hidx(str)
      create_inline_node('hidx', str)
    end

    def inline_idx(str)
      create_inline_node('idx', str)
    end

    def inline_sup(str)
      create_inline_node('sup', str)
    end

    def inline_sub(str)
      create_inline_node('sub', str)
    end

    def image_ext
      # Return the path for image extensions
      # In JSON mode, we just return a simple string
      'images'
    end

    def centering(lines)
      node = AST::Node.new(
        location: location,
        type: 'centering'
      )
      lines.each do |line|
        text_node = AST::TextNode.new(
          location: location,
          content: line
        )
        node.add_child(text_node)
      end
      add_node(node)
    end

    def comment(lines, caption = nil)
      # Comments can be processed in draft mode
      node = AST::Node.new(
        location: location,
        type: 'comment'
      )
      node.content = caption if caption
      lines&.each do |line|
        text_node = AST::TextNode.new(
          location: location,
          content: line
        )
        node.add_child(text_node)
      end
      add_node(node)
    end

    def inline_comment(str)
      create_inline_node('comment', str)
    end

    private

    # Parse caption string that may contain inline elements
    def parse_caption(caption_str)
      return [] if caption_str.nil? || caption_str.empty?

      caption_nodes = []

      # Simple parsing for now - split by inline elements
      words = caption_str.split(/(@<\w+>\{(?:[^}\\]|\\.)*?\})/, -1)
      words.each do |word|
        if word.match?(/\A@<\w+>\{.*?\}\z/)
          # This is an inline element
          create_inline_caption_node(word, caption_nodes)
        else
          # This is plain text
          unless word.empty?
            text_node = AST::TextNode.new(
              location: @location,
              content: word
            )
            caption_nodes << text_node
          end
        end
      end

      caption_nodes
    end

    # Create inline node for captions
    def create_inline_caption_node(str, caption_nodes)
      match = /\A@<(\w+)>\{(.*?)\}\z/.match(str)
      return unless match

      op = match[1]
      arg = match[2]

      inline_node = AST::InlineNode.new(
        location: @location,
        inline_type: op,
        args: [arg]
      )

      # Add text content to inline node
      text_node = AST::TextNode.new(
        location: @location,
        content: arg
      )
      inline_node.add_child(text_node)

      caption_nodes << inline_node
    end
  end
end
