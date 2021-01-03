# Copyright (c) 2013-2020 KADO Masanori, Masayoshi Takahashi, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/textutils'
require 'review/htmlutils'

module ReVIEW
  class MARKDOWNBuilder < Builder
    include TextUtils
    include HTMLUtils

    def extname
      '.md'
    end

    def builder_init_file
      @noindent = nil
      @blank_seen = nil
      @ul_indent = 0
      @chapter.book.image_types = %w[.png .jpg .jpeg .gif .svg]
    end
    private :builder_init_file

    def puts(str)
      @blank_seen = false
      super
    end

    def blank
      unless @blank_seen
        @output.puts
      end
      @blank_seen = true
    end

    def headline(level, _label, caption)
      blank
      prefix = '#' * level
      puts "#{prefix} #{caption}"
      blank
    end

    def quote(lines)
      blank
      puts split_paragraph(lines).map { |line| "> #{line}" }.join("\n> \n")
      blank
    end

    def paragraph(lines)
      if @noindent
        puts %Q(<p class="noindent">#{join_lines_to_paragraph(lines)}</p>)
        puts "\n"
        @noindent = nil
      else
        puts join_lines_to_paragraph(lines)
        puts "\n"
      end
    end

    def noindent
      @noindent = true
    end

    def list_header(id, caption, _lang)
      if get_chap.nil?
        print %Q(リスト#{@chapter.list(id).number} #{compile_inline(caption)}\n\n)
      else
        print %Q(リスト#{get_chap}.#{@chapter.list(id).number} #{compile_inline(caption)}\n\n)
      end
    end

    def list_body(_id, lines, lang)
      lang ||= ''
      puts "```#{lang}"
      lines.each do |line|
        puts detab(line)
      end
      puts '```'
    end

    def listnum_body(lines, lang)
      lang ||= ''
      puts "```#{lang}"
      lines.each_with_index do |line, i|
        puts((i + 1).to_s.rjust(2) + ": #{detab(line)}")
      end
      puts '```'
    end

    def ul_begin
      blank if @ul_indent == 0
      @ul_indent += 1
    end

    def ul_item_begin(lines)
      puts '  ' * (@ul_indent - 1) + '* ' + join_lines_to_paragraph(lines)
    end

    def ul_item_end
    end

    def ul_end
      @ul_indent -= 1
      blank if @ul_indent == 0
    end

    def ol_begin
      blank
    end

    def ol_item(lines, num)
      puts "#{num}. #{join_lines_to_paragraph(lines)}"
    end

    def ol_end
      blank
    end

    def dl_begin
      puts '<dl>'
    end

    def dt(line)
      puts "<dt>#{line}</dt>"
    end

    def dd(lines)
      puts "<dd>#{join_lines_to_paragraph(lines)}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def emlist(lines, caption = nil, lang = nil)
      blank
      if caption.present?
        puts caption
        blank
      end
      lang ||= ''
      puts "```#{lang}"
      lines.each do |line|
        puts detab(line)
      end
      puts '```'
      blank
    end

    def captionblock(type, lines, caption, _specialstyle = nil)
      puts %Q(<div class="#{type}">)
      puts %Q(<p class="caption">#{compile_inline(caption)}</p>) if caption.present?
      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n\n")
      puts '</div>'
    end

    CAPTION_TITLES.each do |name|
      class_eval %Q(
        def #{name}_begin(caption = nil)
          check_nested_minicolumn
          @doc_status[:minicolumn] = '#{name}'
          puts %Q(<div class="#{name}">)
          if caption.present?
            puts %Q(<p class="caption">\#{compile_inline(caption)}</p>)
          end
        end

        def #{name}_end
          puts '</div>'
          @doc_status[:minicolumn] = nil
        end
      ), __FILE__, __LINE__ - 14
    end

    def hr
      puts '----'
    end

    def compile_href(url, label)
      if label.blank?
        label = url
      end
      "[#{label}](#{url})"
    end

    def inline_i(str)
      "*#{str.gsub(/\*/, '\*')}*"
    end

    def inline_em(str)
      "*#{str.gsub(/\*/, '\*')}*"
    end

    def inline_b(str)
      "**#{str.gsub(/\*/, '\*')}**"
    end

    def inline_strong(str)
      "**#{str.gsub(/\*/, '\*')}**"
    end

    def inline_code(str)
      "`#{str}`"
    end

    def inline_sub(str)
      "<sub>#{str}</sub>"
    end

    def inline_sup(str)
      "<sup>#{str}</sup>"
    end

    def inline_tt(str)
      "`#{str}`"
    end

    def inline_u(str)
      "<u>#{str}</u>"
    end

    def inline_ins(str)
      "<ins>#{str}</ins>"
    end

    def inline_del(str)
      "~~#{str}~~"
    end

    def image_image(id, caption, _metric)
      blank
      puts "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(%r{\A\./}, '')})"
      blank
    end

    def image_dummy(_id, _caption, lines)
      puts lines.join
    end

    def inline_img(id)
      "#{I18n.t('image')}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
    end

    def inline_dtp(str)
      "<!-- DTP:#{str} -->"
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if n.present? && chap.number && over_secnolevel?(n)
        str = I18n.t('hd_quote', [n, compile_inline(chap.headline(id).caption)])
      else
        str = I18n.t('hd_quote_without_number', compile_inline(chap.headline(id).caption))
      end
      if @book.config['chapterlink']
        if @chapter == chap
          anchor = 'h' + n.tr('.', '-')
          %Q(<a href="##{anchor}">#{str}</a>)
        else
          warn 'MARKDOWNBuilder does not support links to other chapters'
          str
        end
      else
        str
      end
    rescue KeyError
      error "unknown headline: #{id}"
    end

    def indepimage(_lines, id, caption = '', _metric = nil)
      blank
      puts "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(%r{\A\./}, '')})"
      blank
    end

    def pagebreak
      puts '{pagebreak}'
    end

    def image_ext
      'jpg'
    end

    def cmd(lines, caption = nil)
      if caption.present?
        puts caption
        blank
      end
      puts '```shell-session'
      lines.each do |line|
        puts detab(line)
      end
      puts '```'
    end

    def table_rows(sepidx, rows)
      if sepidx
        sepidx.times do
          tr(rows.shift.map { |s| th(s) })
        end
        table_border(rows.first.size)
        rows.each do |cols|
          tr(cols.map { |s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr([th(h)] + cs.map { |s| td(s) })
        end
      end
    end

    def table_header(id, caption)
      if id.nil?
        puts compile_inline(caption)
      elsif get_chap
        puts %Q(#{I18n.t('table')}#{I18n.t('format_number_header', [get_chap, @chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)})
      else
        puts %Q(#{I18n.t('table')}#{I18n.t('format_number_header_without_chapter', [@chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)})
      end
      blank
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts "|#{rows.join('|')}|"
    end

    def table_border(ncols)
      puts((0..ncols).map { '|' }.join(':--'))
    end

    def th(str)
      str
    end

    def td(str)
      str
    end

    def table_end
      blank
    end

    def footnote(id, str)
      puts "[^#{id}]: #{compile_inline(str)}"
      blank
    end

    def inline_fn(id)
      "[^#{id}]"
    end

    def inline_br(_str)
      "\n"
    end

    def nofunc_text(str)
      str
    end

    def compile_ruby(base, ruby)
      if @book.htmlversion == 5
        %Q(<ruby>#{escape(base)}<rp>#{I18n.t('ruby_prefix')}</rp><rt>#{escape(ruby)}</rt><rp>#{I18n.t('ruby_postfix')}</rp></ruby>)
      else
        %Q(<ruby><rb>#{escape(base)}</rb><rp>#{I18n.t('ruby_prefix')}</rp><rt>#{ruby}</rt><rp>#{I18n.t('ruby_postfix')}</rp></ruby>)
      end
    end

    def compile_kw(word, alt)
      %Q(<b class="kw">) +
        if alt
          escape_html(word + " (#{alt.strip})")
        else
          escape_html(word)
        end +
        "</b><!-- IDX:#{escape_comment(escape_html(word))} -->"
    end

    def comment(lines, comment = nil)
      return unless @book.config['draft']
      lines ||= []
      unless comment.blank?
        lines.unshift(comment)
      end
      str = lines.join('<br />')
      puts %Q(<div class="red">#{escape(str)}</div>)
    end

    def inline_icon(id)
      begin
        "![](#{@chapter.image(id).path.sub(%r{\A\./}, '')})"
      rescue
        warn "image not bound: #{id}"
        %Q(<pre>missing image: #{id}</pre>)
      end
    end

    def inline_comment(str)
      if @book.config['draft']
        %Q(<span class="red">#{escape(str)}</span>)
      else
        ''
      end
    end

    def flushright(lines)
      puts %Q(<div class="flushright">)
      puts split_paragraph(lines).join("\n")
      puts %Q(</div>)
    end
  end
end # module ReVIEW
