# -*- coding: utf-8 -*-
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
      @blank_seen = nil
      @ul_indent = 0
      @chapter.book.image_types = %w(.png .jpg .jpeg .gif .svg)
    end
    private :builder_init_file

    def blank_reset
      @blank_seen = false
    end

#    def puts(str)
#      @blank_seen = false
#      "#{str}\n"
#    end

    def blank
      buf = ""
      unless @blank_seen
        buf = "\n"
      end
      @blank_seen = true
      buf
    end

    def headline(level, label, caption)
      buf = ""
      buf << blank
      prefix = "#" * level
      buf << "#{prefix} #{caption}\n"
      blank_reset
      buf << "\n"
      buf
    end

    def quote(lines)
      buf = ""
      buf << blank
      buf << lines.map{|line| line.chomp!;line.chomp!;"> #{line}"}.join("\n") << "\n"
      blank_reset
      buf << "\n"
      buf
    end

    def paragraph(lines)
      buf = lines.join << "\n"
      blank_reset
      buf << "\n"
      buf
    end

    def list_header(id, caption, lang)
      lang ||= ""
      if get_chap.nil?
        %Q[リスト#{@chapter.list(id).number} #{compile_inline(caption)}\n\n] + "```#{lang}\n"
      else
        %Q[リスト#{get_chap}.#{@chapter.list(id).number} #{compile_inline(caption)}\n\n] + "```#{lang}\n"
      end
    end

    def list_body(id, lines, lang)
      buf = ""
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << '```' << "\n"
      buf
    end

    def ul_begin
      buf = ""
      buf << blank if @ul_indent == 0
      @ul_indent += 1
      buf
    end

    def ul_item(lines)
      blank_reset
      "  " * (@ul_indent - 1) + "* " + "#{lines.join}" + "\n"
    end

    def ul_item_begin(lines)
      blank_reset
      "  " * (@ul_indent - 1) + "* " + "#{lines.join}" + "\n"
    end

    def ul_item_end
      ""
    end

    def ul_end
      buf = ""
      @ul_indent -= 1
      buf << blank if @ul_indent == 0
      buf
    end

    def ol_begin
      buf = ""
      buf << blank
      buf
    end

    def ol_item(lines, num)
      buf = ""
      buf << "#{num}. #{lines.join}" << "\n"
      blank_reset
      buf
    end

    def ol_end
      buf = ""
      buf << blank
      buf
    end

    def dl_begin
      "<dl>\n"
    end

    def dt(line)
      "<dt>#{line}</dt>\n"
    end

    def dd(lines)
      "<dd>#{lines.join}</dd>\n"
    end

    def dl_end
      "</dl>\n"
    end

    def emlist(lines, caption = nil, lang = nil)
      buf = ""
      buf << blank
      if caption
        buf << caption << "\n\n"
      end
      lang ||= ""
      buf << "```#{lang}\n"
      blank_reset
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << "```\n"
      buf << blank
      buf
    end

    def hr
      buf << "----\n"
      blank_reset
      buf
    end

    def compile_href(url, label)
      label = url if label.blank?
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

    def inline_tt(str)
      "`#{str}`"
    end


    def image_image(id, caption, metric)
      buf = ""
      buf << blank
      buf << "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(/\A\.\//, "")})" << "\n"
      blank_reset
      buf << blank
      buf
    end

    def image_dummy(id, caption, lines)
      buf = ""
      buf << lines.join << "\n"
      blank_reset
      buf
    end

    def inline_img(id)
      "#{I18n.t("image")}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      "[UnknownImage:#{id}]"
    end

    def indepimage(id, caption="", metric=nil)
      buf = ""
      buf << blank
      buf << "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(/\A\.\//, "")})" << "\n"
      blank_reset
      buf << blank
      buf
    end

    def pagebreak
      buf = ""
      buf << "{pagebreak}" << "\n"
      buf
    end

    def image_ext
      "jpg"
    end

    def cmd(lines, caption = nil)
      buf = ""
      buf << "```shell-session" << "\n"
      blank_reset
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << "```" << "\n"
      buf
    end

    def table(lines, id = nil, caption = nil)
      buf = ""
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map{|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        buf << table_header(id, caption) unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      buf << table_begin(rows.first.size)
      return buf if rows.empty?
      if sepidx
        sepidx.times do
          buf << tr(rows.shift.map{|s| th(s) })
        end
        buf << table_border(rows.first.size)
        rows.each do |cols|
          buf << tr(cols.map{|s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr([th(h)] + cs.map {|s| td(s) })
        end
      end
      buf << table_end
      buf
    end

    def table_header(id, caption)
      buf = ""
      if get_chap.nil?
        buf << %Q[#{I18n.t("table")}#{I18n.t("format_number_header_without_chapter", [@chapter.table(id).number])}#{I18n.t("caption_prefix")}#{compile_inline(caption)}] << "\n"
      else
        buf << %Q[#{I18n.t("table")}#{I18n.t("format_number_header", [get_chap, @chapter.table(id).number])}#{I18n.t("caption_prefix")}#{compile_inline(caption)}] << "\n"
      end
      blank_reset
      buf << blank
      buf
    end

    def table_begin(ncols)
      ""
    end

    def tr(rows)
      "|#{rows.join("|")}|\n"
    end

    def table_border(ncols)
      blank_reset
      (0..ncols).map{"|"}.join(":--") + "\n"
    end

    def th(str)
      "#{str}"
    end

    def td(str)
      "#{str}"
    end

    def table_end
      buf = ""
      buf << blank
      buf
    end

    def footnote(id, str)
      buf = ""
      buf << "[^#{id}]: #{compile_inline(str)}" << "\n"
      blank_reset
      buf << blank
      buf
    end

    def inline_fn(id)
      "[^#{id}]"
    end

    def inline_br(str)
      "\n"
    end

    def nofunc_text(str)
      str
    end

    def compile_ruby(base, ruby)
      if @book.htmlversion == 5
        %Q[<ruby>#{base}<rp>#{I18n.t("ruby_prefix")}</rp><rt>#{ruby}</rt><rp>#{I18n.t("ruby_postfix")}</rp></ruby>]
      else
        %Q[<ruby><rb>#{base}</rb><rp>#{I18n.t("ruby_prefix")}</rp><rt>#{ruby}</rt><rp>#{I18n.t("ruby_postfix")}</rp></ruby>]
      end
    end

  end

end # module ReVIEW
