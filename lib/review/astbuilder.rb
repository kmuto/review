# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'

module ReVIEW
  class ASTBuilder < Builder
    def initialize(strict = false, *args, **kwargs)
      super
      @document = nil
      @current_container = nil
      @stack = []
    end

    def bind(compiler, chapter, location)
      super
      @document = {
        'type' => 'document',
        'children' => []
      }
      @current_container = @document
    end

    def result
      @document
    end

    def headline(level, label, caption)
      node = {
        'type' => 'heading',
        'attrs' => {
          'level' => level,
          'label' => label
        },
        'value' => caption,
        'children' => []
      }
      add_node(node)
    end

    def paragraph(lines)
      node = {
        'type' => 'paragraph',
        'value' => lines.join("\n"),
        'children' => []
      }

      # Process inline elements if present
      processed_children = lines.map do |line|
        # Simple inline processing - this would need to be more sophisticated
        # For now, just add as text
        {
          'type' => 'text',
          'value' => line
        }
      end

      node['children'] = processed_children
      add_node(node)
    end

    def list(lines, id, caption, lang = nil)
      node = {
        'type' => 'list',
        'attrs' => {
          'id' => id,
          'caption' => caption,
          'language' => lang
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'list_item', 'value' => line } }
      }
      add_node(node)
    end

    def listnum(lines, id, caption, lang = nil)
      node = {
        'type' => 'listnum',
        'attrs' => {
          'id' => id,
          'caption' => caption,
          'language' => lang
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'list_item', 'value' => line } }
      }
      add_node(node)
    end

    def emlist(lines, caption = nil, lang = nil)
      node = {
        'type' => 'emlist',
        'attrs' => {
          'caption' => caption,
          'language' => lang
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'list_item', 'value' => line } }
      }
      add_node(node)
    end

    def emlistnum(lines, caption = nil, lang = nil)
      node = {
        'type' => 'emlistnum',
        'attrs' => {
          'caption' => caption,
          'language' => lang
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'list_item', 'value' => line } }
      }
      add_node(node)
    end

    def cmd(lines, caption = nil)
      node = {
        'type' => 'cmd',
        'attrs' => {
          'caption' => caption
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'cmd_line', 'value' => line } }
      }
      add_node(node)
    end

    def source(lines, caption = nil, lang = nil)
      node = {
        'type' => 'source',
        'attrs' => {
          'caption' => caption,
          'language' => lang
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'source_line', 'value' => line } }
      }
      add_node(node)
    end

    def image(_lines, id, caption, metric = nil)
      node = {
        'type' => 'image',
        'attrs' => {
          'id' => id,
          'caption' => caption,
          'metric' => metric
        },
        'value' => '',
        'children' => []
      }
      add_node(node)
    end

    def indepimage(lines, id, caption, metric = nil)
      image(lines, id, caption, metric)
    end

    def numberlessimage(lines, id, caption, metric = nil)
      image(lines, id, caption, metric)
    end

    def table(lines, id = nil, caption = nil)
      node = {
        'type' => 'table',
        'attrs' => {
          'id' => id,
          'caption' => caption
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'table_row', 'value' => line } }
      }
      add_node(node)
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    # Minicolumn blocks
    def note(lines, caption = nil)
      minicolumn('note', lines, caption)
    end

    def memo(lines, caption = nil)
      minicolumn('memo', lines, caption)
    end

    def tip(lines, caption = nil)
      minicolumn('tip', lines, caption)
    end

    def info(lines, caption = nil)
      minicolumn('info', lines, caption)
    end

    def warning(lines, caption = nil)
      minicolumn('warning', lines, caption)
    end

    def important(lines, caption = nil)
      minicolumn('important', lines, caption)
    end

    def caution(lines, caption = nil)
      minicolumn('caution', lines, caption)
    end

    def notice(lines, caption = nil)
      minicolumn('notice', lines, caption)
    end

    # List structures
    def ul_begin
      start_container('ul')
    end

    def ul_item_begin(lines)
      node = {
        'type' => 'ul_item',
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    def ul_item_end
      # no-op
    end

    def ul_end
      end_container
    end

    def ol_begin
      start_container('ol')
    end

    def ol_item(lines, num)
      node = {
        'type' => 'ol_item',
        'attrs' => {
          'number' => num
        },
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    def ol_end
      end_container
    end

    def dl_begin
      start_container('dl')
    end

    def dt(str)
      node = {
        'type' => 'dt',
        'value' => str,
        'children' => []
      }
      add_node(node)
    end

    def dd(lines)
      node = {
        'type' => 'dd',
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    def dl_end
      end_container
    end

    # Inline element processing
    def compile_inline(str)
      # Basic inline processing - this should be more sophisticated
      # For now, return the string as-is
      str
    end

    def nofunc_text(str)
      str
    end

    # Inline element methods that create nodes for nested processing
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

    def inline_hd(str)
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

    def inline_embed(str)
      create_inline_node('embed', str)
    end

    def inline_br(_str)
      create_inline_node('br', '')
    end

    # Additional block commands
    def lead(lines)
      node = {
        'type' => 'lead',
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    def noindent
      # No-op for AST
    end

    def footnote(id, str)
      node = {
        'type' => 'footnote',
        'attrs' => {
          'id' => id
        },
        'value' => str,
        'children' => []
      }
      add_node(node)
    end

    def olnum(num)
      # Store starting number for ordered lists
      @ol_num = num.to_i
    end

    def quote(lines)
      node = {
        'type' => 'quote',
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    def embed(lines, arg = nil)
      node = {
        'type' => 'embed',
        'attrs' => {
          'arg' => arg
        },
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    def raw(arg)
      node = {
        'type' => 'raw',
        'attrs' => {
          'arg' => arg
        },
        'value' => '',
        'children' => []
      }
      add_node(node)
    end

    # Child block support
    def beginchild
      start_container('child')
    end

    def endchild
      end_container
    end

    # Read block support
    def read(lines)
      node = {
        'type' => 'read',
        'value' => lines.join("\n"),
        'children' => []
      }
      add_node(node)
    end

    # Minicolumn begin/end methods
    def note_begin(caption = nil)
      start_minicolumn('note', caption)
    end

    def note_end
      end_container
    end

    def memo_begin(caption = nil)
      start_minicolumn('memo', caption)
    end

    def memo_end
      end_container
    end

    def tip_begin(caption = nil)
      start_minicolumn('tip', caption)
    end

    def tip_end
      end_container
    end

    def info_begin(caption = nil)
      start_minicolumn('info', caption)
    end

    def info_end
      end_container
    end

    def warning_begin(caption = nil)
      start_minicolumn('warning', caption)
    end

    def warning_end
      end_container
    end

    def important_begin(caption = nil)
      start_minicolumn('important', caption)
    end

    def important_end
      end_container
    end

    def caution_begin(caption = nil)
      start_minicolumn('caution', caption)
    end

    def caution_end
      end_container
    end

    def notice_begin(caption = nil)
      start_minicolumn('notice', caption)
    end

    def notice_end
      end_container
    end

    # Section types
    def nonum_begin(level, label, caption)
      node = {
        'type' => 'heading',
        'attrs' => {
          'level' => level,
          'label' => label,
          'nonum' => true
        },
        'value' => caption,
        'children' => []
      }
      add_node(node)
    end

    def nonum_end(level)
      # No-op
    end

    def nodisp_begin(level, label, caption)
      node = {
        'type' => 'heading',
        'attrs' => {
          'level' => level,
          'label' => label,
          'nodisp' => true
        },
        'value' => caption,
        'children' => []
      }
      add_node(node)
    end

    def nodisp_end(level)
      # No-op
    end

    private

    def add_node(node)
      @current_container['children'] << node
    end

    def start_container(type)
      container = {
        'type' => type,
        'children' => []
      }
      add_node(container)
      @stack.push(@current_container)
      @current_container = container
    end

    def end_container
      @current_container = @stack.pop if @stack.any?
    end

    def minicolumn(type, lines, caption)
      node = {
        'type' => 'minicolumn',
        'attrs' => {
          'name' => type,
          'caption' => caption
        },
        'value' => lines.join("\n"),
        'children' => lines.map { |line| { 'type' => 'paragraph', 'value' => line } }
      }
      add_node(node)
    end

    def create_inline_node(command, content)
      {
        'type' => 'inline_command',
        'attrs' => {
          'command' => command
        },
        'value' => content,
        'children' => []
      }
    end

    def start_minicolumn(type, caption)
      container = {
        'type' => 'minicolumn',
        'attrs' => {
          'name' => type,
          'caption' => caption
        },
        'children' => []
      }
      add_node(container)
      @stack.push(@current_container)
      @current_container = container
    end
  end
end
