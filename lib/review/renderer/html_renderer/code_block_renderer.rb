# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/renderer/base'
require 'review/textutils'

module ReVIEW
  module Renderer
    class HtmlRenderer
      # CodeBlockRenderer handles rendering of code blocks (list, emlist, source, cmd, etc.)
      # This class encapsulates the logic for different code block types and their captions.
      # Inherits from Base to get render_children and other common functionality.
      class CodeBlockRenderer < Base
        include ReVIEW::HTMLUtils
        include ReVIEW::TextUtils

        def initialize(chapter, parent:)
          super(chapter)
          @parent = parent
          # NOTE: @chapter and @book are now set by Base's initialize
        end

        # Main entry point for rendering code blocks
        def render(node)
          case node.code_type
          when :emlist      then render_emlist_block(node)
          when :emlistnum   then render_emlistnum_block(node)
          when :list        then render_list_block(node)
          when :listnum     then render_listnum_block(node)
          when :source      then render_source_block(node)
          when :cmd         then render_cmd_block(node)
          else                   render_fallback_code_block(node)
          end
        end

        private

        # Code block rendering methods for specific types

        def render_emlist_block(node)
          lines_content = render_children(node)
          processed_content = format_code_content(lines_content, node.lang)

          code_block_wrapper(
            node,
            div_class: 'emlist-code',
            pre_class: build_pre_class('emlist', node.lang),
            content: processed_content,
            caption_style: :top_bottom
          )
        end

        def render_emlistnum_block(node)
          lines_content = render_children(node)
          numbered_lines = format_emlistnum_content(lines_content, node.lang)

          code_block_wrapper(
            node,
            div_class: 'emlistnum-code',
            pre_class: build_pre_class('emlist', node.lang),
            content: numbered_lines,
            caption_style: :top_bottom
          )
        end

        def render_list_block(node)
          lines_content = render_children(node)
          processed_content = format_code_content(lines_content, node.lang)

          code_block_wrapper(
            node,
            div_class: 'caption-code',
            pre_class: build_pre_class('list', node.lang),
            content: processed_content,
            caption_style: :numbered
          )
        end

        def render_listnum_block(node)
          lines_content = render_children(node)
          numbered_lines = format_listnum_content(lines_content, node.lang)

          code_block_wrapper(
            node,
            div_class: 'code',
            pre_class: build_pre_class('list', node.lang, with_highlight: false),
            content: numbered_lines,
            caption_style: :numbered
          )
        end

        def render_source_block(node)
          lines_content = render_children(node)
          processed_content = format_code_content(lines_content, node.lang)

          code_block_wrapper(
            node,
            div_class: 'source-code',
            pre_class: 'source',
            content: processed_content,
            caption_style: :top_bottom
          )
        end

        def render_cmd_block(node)
          lines_content = render_children(node)
          processed_content = format_code_content(lines_content, node.lang)

          code_block_wrapper(
            node,
            div_class: 'cmd-code',
            pre_class: 'cmd',
            content: processed_content,
            caption_style: :top_bottom
          )
        end

        def render_fallback_code_block(node)
          lines_content = render_children(node)
          processed_content = format_code_content(lines_content)

          code_block_wrapper(
            node,
            div_class: 'caption-code',
            pre_class: '',
            content: processed_content,
            caption_style: :none
          )
        end

        # Code block helper methods

        def code_block_wrapper(node, div_class:, pre_class:, content:, caption_style:)
          id_attr = node.id ? %Q( id="#{normalize_id(node.id)}") : ''

          caption_top = render_code_caption(node, caption_style, :top)
          caption_bottom = render_code_caption(node, caption_style, :bottom)

          %Q(<div#{id_attr} class="#{div_class}">\n#{caption_top}<pre class="#{pre_class}">#{content}</pre>\n#{caption_bottom}</div>\n)
        end

        def render_code_caption(node, style, position)
          return '' unless node.caption

          case style
          when :top_bottom
            return '' unless position == :top ? @parent.caption_top?('list') : !@parent.caption_top?('list')

            caption_content = render_children(node.caption)
            %Q(<p class="caption">#{caption_content}</p>\n)
          when :numbered
            return '' unless position == :top

            caption_content = render_children(node.caption)
            list_number = generate_list_header(node.id, caption_content)
            %Q(<p class="caption">#{list_number}</p>\n)
          else
            ''
          end
        end

        # Build pre tag class attribute with optional language and highlight
        # @param base_class [String] base CSS class (e.g., 'emlist', 'list')
        # @param lang [String, nil] language identifier for syntax highlighting
        # @param with_highlight [Boolean] whether to add 'highlight' class
        # @return [String] space-separated class names
        def build_pre_class(base_class, lang, with_highlight: true)
          classes = [base_class]
          classes << "language-#{lang}" if lang
          classes << 'highlight' if with_highlight && highlight?
          classes.join(' ')
        end

        # Code processing methods (moved from CodeProcessingHelpers)

        # Process code lines exactly like HTMLBuilder does
        def format_code_content(lines_content, lang = nil)
          # HTMLBuilder uses: lines.inject('') { |i, j| i + detab(j) + "\n" }
          # We need to emulate this exact behavior to match Builder output

          lines = lines_content.split("\n")

          # Use inject pattern exactly like HTMLBuilder for consistency
          body = lines.inject('') { |i, j| i + detab(j) + "\n" }

          # Apply highlighting if enabled, otherwise return processed body
          highlight(body: body, lexer: lang, format: 'html')
        end

        # Add line numbers like HTMLBuilder's emlistnum method
        def format_emlistnum_content(content, lang = nil)
          # HTMLBuilder processes lines with detab first, then adds line numbers
          lines = content.split("\n")
          # Remove last empty line if present to match HTMLBuilder behavior
          lines.pop if lines.last && lines.last.empty?

          # Use inject pattern exactly like HTMLBuilder for consistency
          body = lines.inject('') { |i, j| i + detab(j) + "\n" }
          first_line_number = line_num || 1 # Use line_num like HTMLBuilder (supports firstlinenum)

          if highlight?
            # Use highlight with line numbers like HTMLBuilder
            highlight(body: body, lexer: lang, format: 'html', linenum: true, options: { linenostart: first_line_number })
          else
            # Fallback: manual line numbering like HTMLBuilder does when highlight is off
            lines.map.with_index(first_line_number) do |line, i|
              "#{i.to_s.rjust(2)}: #{detab(line)}"
            end.join("\n") + "\n"
          end
        end

        # Add line numbers like HTMLBuilder's listnum method
        def format_listnum_content(content, lang = nil)
          # HTMLBuilder processes lines with detab first, then adds line numbers
          lines = content.split("\n")
          # Remove last empty line if present to match HTMLBuilder behavior
          lines.pop if lines.last && lines.last.empty?

          # Use inject pattern exactly like HTMLBuilder for consistency
          body = lines.inject('') { |i, j| i + detab(j) + "\n" }
          first_line_number = line_num || 1 # Use line_num like HTMLBuilder

          hs = highlight(body: body, lexer: lang, format: 'html', linenum: true,
                         options: { linenostart: first_line_number })

          if highlight?
            hs
          else
            # Fallback: manual line numbering like HTMLBuilder does when highlight is off
            lines.map.with_index(first_line_number) do |line, i|
              i.to_s.rjust(2) + ': ' + detab(line)
            end.join("\n") + "\n"
          end
        end

        # Check if highlight is enabled like HTMLBuilder
        def highlight?
          highlighter.highlight?('html')
        end

        # Highlight code using the new Highlighter class
        def highlight(body:, lexer: nil, format: 'html', linenum: false, options: {}, location: nil)
          highlighter.highlight(
            body: body,
            lexer: lexer,
            format: format,
            linenum: linenum,
            options: options,
            location: location
          )
        end

        def highlighter
          @highlighter ||= ReVIEW::Highlighter.new(config)
        end

        # Generate list header like HTMLBuilder's list_header method
        def generate_list_header(id, caption)
          list_item = @chapter.list(id)
          list_num = list_item.number
          chapter_num = @chapter.number

          if chapter_num
            "#{I18n.t('list')}#{I18n.t('format_number_header', [chapter_num, list_num])}#{I18n.t('caption_prefix')}#{caption}"
          else
            "#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [list_num])}#{I18n.t('caption_prefix')}#{caption}"
          end
        rescue KeyError
          raise NotImplementedError, "no such list: #{id}"
        end

        # Delegation methods to parent renderer for state-specific methods
        # render_children needs to delegate to parent to use parent's visit methods
        # because Base.render_children calls self.visit, which would use CodeBlockRenderer's
        # visit methods instead of HtmlRenderer's visit methods
        # line_num is delegated to parent
        def render_children(node)
          @parent.render_children(node)
        end

        def line_num
          @parent.line_num
        end
      end
    end
  end
end
