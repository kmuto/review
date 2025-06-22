# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/textutils'
require 'json'

module ReVIEW
  # JSONBuilder - Generate JSON output from Re:VIEW markup
  #
  # This builder generates structured JSON output representing the content
  # of Re:VIEW documents. Unlike the previous JSONBuilder, this version:
  #
  # 1. Does NOT generate AST internally
  # 2. Works as a standard Builder (like HTMLBuilder, LaTeXBuilder)
  # 3. Can be combined with Pure AST Mode for comprehensive JSON generation
  # 4. Outputs clean, readable JSON suitable for further processing
  #
  # Usage:
  #   builder = ReVIEW::JSONBuilder.new
  #   compiler = ReVIEW::Compiler.new(builder)
  #   result = compiler.compile(chapter)  # Returns JSON string
  #
  # For AST + JSON combination:
  #   builder = ReVIEW::JSONBuilder.new
  #   compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
  #   json_output = compiler.compile(chapter)  # JSON output
  #   ast_structure = compiler.ast_result      # AST structure
  class JSONBuilder < Builder
    include TextUtils

    def initialize(strict = false, *args, **kwargs)
      super
      @json_content = []
      @current_level = 0
    end

    def result
      {
        'type' => 'document',
        'content' => @json_content
      }.to_json
    end

    # Headline processing
    def headline(level, label, caption)
      # Handle different caption types
      caption_text = case caption
                     when String
                       caption
                     else
                       # For CaptionNode or other objects, extract text content
                       if caption.respond_to?(:children) && caption.children.any?
                         caption.children.map do |child|
                           child.respond_to?(:content) ? child.content : child.to_s
                         end.join
                       else
                         caption.to_s
                       end
                     end

      @json_content << {
        'type' => 'headline',
        'level' => level,
        'label' => label,
        'caption' => caption_text
      }
    end

    # Paragraph processing
    def paragraph(lines)
      content = lines.join("\n")
      @json_content << {
        'type' => 'paragraph',
        'content' => content
      }
    end

    # Lists
    def ul_begin
      @current_list = {
        'type' => 'unordered_list',
        'items' => []
      }
    end

    def ul_item_begin(lines)
      @current_list ||= { 'type' => 'unordered_list', 'items' => [] }
      @current_list['items'] << lines.join("\n")
    end

    def ul_item_end
      # No-op: item content already added in ul_item_begin
    end

    def ul_end
      @json_content << @current_list
      @current_list = nil
    end

    def ol_begin
      @current_list = {
        'type' => 'ordered_list',
        'items' => []
      }
    end

    def ol_item(lines, num)
      @current_list ||= { 'type' => 'ordered_list', 'items' => [] }
      @current_list['items'] << {
        'number' => num,
        'content' => lines.join("\n")
      }
    end

    def ol_end
      @json_content << @current_list
      @current_list = nil
    end

    def dl_begin
      @current_list = {
        'type' => 'definition_list',
        'items' => []
      }
    end

    def dt(line)
      @current_dt = line
    end

    def dd(lines)
      @current_list ||= { 'type' => 'definition_list', 'items' => [] }
      @current_list['items'] << {
        'term' => @current_dt,
        'definition' => lines.join("\n")
      }
    end

    def dl_end
      @json_content << @current_list
      @current_list = nil
    end

    # Code blocks
    def list(lines, id, caption, lang = nil)
      @json_content << {
        'type' => 'code_block',
        'id' => id,
        'caption' => caption.to_s,
        'lang' => lang,
        'lines' => lines,
        'numbered' => false
      }
    end

    def listnum(lines, id, caption, lang = nil)
      @json_content << {
        'type' => 'code_block',
        'id' => id,
        'caption' => caption.to_s,
        'lang' => lang,
        'lines' => lines,
        'numbered' => true
      }
    end

    def emlist(lines, caption = nil, lang = nil)
      @json_content << {
        'type' => 'code_block',
        'caption' => caption.to_s,
        'lang' => lang,
        'lines' => lines,
        'numbered' => false
      }
    end

    def emlistnum(lines, caption = nil, lang = nil)
      @json_content << {
        'type' => 'code_block',
        'caption' => caption.to_s,
        'lang' => lang,
        'lines' => lines,
        'numbered' => true
      }
    end

    def cmd(lines, caption = nil)
      @json_content << {
        'type' => 'command_block',
        'caption' => caption.to_s,
        'lines' => lines
      }
    end

    # Tables
    def table(lines, id, caption)
      headers, *rows = parse_table_lines(lines)
      @json_content << {
        'type' => 'table',
        'id' => id,
        'caption' => caption.to_s,
        'headers' => headers,
        'rows' => rows
      }
    end

    def emtable(lines, caption = nil)
      headers, *rows = parse_table_lines(lines)
      @json_content << {
        'type' => 'table',
        'caption' => caption.to_s,
        'headers' => headers,
        'rows' => rows
      }
    end

    def imgtable(lines, id, caption, metric = nil)
      @json_content << {
        'type' => 'image_table',
        'id' => id,
        'caption' => caption.to_s,
        'metric' => metric,
        'lines' => lines
      }
    end

    # Images
    def image(_lines, id, caption, metric = nil)
      @json_content << {
        'type' => 'image',
        'id' => id,
        'caption' => caption.to_s,
        'metric' => metric
      }
    end

    # Math equations
    def texequation(lines, id, caption)
      @json_content << {
        'type' => 'equation',
        'id' => id,
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def indepimage(_lines, id, caption = nil, metric = nil)
      @json_content << {
        'type' => 'independent_image',
        'id' => id,
        'caption' => caption.to_s,
        'metric' => metric
      }
    end

    def numberlessimage(_lines, id, caption = nil, metric = nil)
      @json_content << {
        'type' => 'numberless_image',
        'id' => id,
        'caption' => caption.to_s,
        'metric' => metric
      }
    end

    # Quotes and blocks
    def quote(lines)
      @json_content << {
        'type' => 'quote',
        'content' => lines.join("\n")
      }
    end

    def memo(lines, caption = nil)
      @json_content << {
        'type' => 'memo',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def tip(lines, caption = nil)
      @json_content << {
        'type' => 'tip',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def info(lines, caption = nil)
      @json_content << {
        'type' => 'info',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def warning(lines, caption = nil)
      @json_content << {
        'type' => 'warning',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def important(lines, caption = nil)
      @json_content << {
        'type' => 'important',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def caution(lines, caption = nil)
      @json_content << {
        'type' => 'caution',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def notice(lines, caption = nil)
      @json_content << {
        'type' => 'notice',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    def note(lines, caption = nil)
      @json_content << {
        'type' => 'note',
        'caption' => caption.to_s,
        'content' => lines.join("\n")
      }
    end

    # Embed blocks
    def embed(lines, arg = nil)
      @json_content << {
        'type' => 'embed',
        'arg' => arg,
        'content' => lines.join("\n")
      }
    end

    def raw(str)
      @json_content << {
        'type' => 'raw',
        'content' => str.to_s
      }
    end

    # Inline elements
    def inline_b(str)
      %Q({"type": "inline", "element": "b", "content": #{str.to_json}})
    end

    def inline_i(str)
      %Q({"type": "inline", "element": "i", "content": #{str.to_json}})
    end

    def inline_code(str)
      %Q({"type": "inline", "element": "code", "content": #{str.to_json}})
    end

    def inline_tt(str)
      %Q({"type": "inline", "element": "tt", "content": #{str.to_json}})
    end

    def inline_ruby(str)
      %Q({"type": "inline", "element": "ruby", "content": #{str.to_json}})
    end

    def inline_kw(str)
      %Q({"type": "inline", "element": "kw", "content": #{str.to_json}})
    end

    def inline_href(str)
      %Q({"type": "inline", "element": "href", "content": #{str.to_json}})
    end

    def inline_eq(str)
      %Q({"type": "inline", "element": "eq", "content": #{str.to_json}})
    end

    def inline_img(str)
      %Q({"type": "inline", "element": "img", "content": #{str.to_json}})
    end

    def inline_table(str)
      %Q({"type": "inline", "element": "table", "content": #{str.to_json}})
    end

    # Text processing (inherited from Builder but customized for JSON)
    def nofunc_text(str)
      str.to_s
    end

    private

    def parse_table_lines(lines)
      return [[], []] if lines.empty?

      separator_index = lines.find_index { |line| line.strip.match?(/^=+$/) }

      if separator_index
        headers = lines[0...separator_index].map { |line| parse_table_row(line) }
        rows = (lines[(separator_index + 1)..-1] || []).map { |line| parse_table_row(line) }
      else
        headers = []
        rows = lines.map { |line| parse_table_row(line) }
      end

      [headers, rows]
    end

    def parse_table_row(line)
      line.split("\t").map(&:strip)
    end
  end
end
