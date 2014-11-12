# -*- coding: utf-8 -*-
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/textutils'

module ReVIEW

  class MARKDOWNBuilder < Builder
    include TextUtils

    def extname
      '.md'
    end

    def builder_init_file
      @ul_indent = 0
      @chapter.book.image_types = %w( .png .jpg .jpeg .gif .svg )
    end
    private :builder_init_file

    def puts(str)
      @blank_seen = false
      super
    end

    def blank
      @output.puts unless @blank_seen
      @blank_seen = true
    end

    def headline(level, label, caption)
      blank
      prefix = "#" * level
      puts "#{prefix} #{caption}"
      blank
    end

    def quote(lines)
      blank
      puts split_paragraph(lines).map{|line| "> #{line}"}.join("\n> \n")
      blank
    end

    def paragraph(lines)
      puts lines.join
      puts "\n"
    end

    def list_header(id, caption)
      if get_chap.nil?
        puts %Q[リスト#{@chapter.list(id).number} #{compile_inline(caption)}]
      else
        puts %Q[リスト#{get_chap}.#{@chapter.list(id).number} #{compile_inline(caption)}]
      end
      puts '```'
    end

    def list_body(id, lines)
      lines.each do |line|
        puts detab(line)
      end
      puts '```'
    end

    def ul_begin
      blank if @ul_indent == 0
      @ul_indent += 1
    end

    def ul_item(lines)
      puts "  " * (@ul_indent - 1) + "* " + "#{lines.join}"
    end

    def ul_item_begin(lines)
      puts "  " * (@ul_indent - 1) + "* " + "#{lines.join}"
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
      puts "#{num}. #{lines.join}"
    end

    def ol_end
      blank
    end

    def emlist(lines, caption = nil)
      blank
      if caption
        puts caption
      end
      puts "```"
      lines.each do |line|
        puts detab(line)
      end
      puts "```"
      blank
    end

    def hr
      puts "----"
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
      blank
      puts "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(/\A\.\//, "")})"
      blank
    end

    def image_dummy(id, caption, lines)
      puts lines.join
    end

    def inline_img(id)
      "#{I18n.t("image")}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
    end

    def indepimage(id, caption="", metric=nil)
      blank
      puts "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(/\A\.\//, "")})"
      blank
    end

    def pagebreak
      puts "{pagebreak}"
    end

    def image_ext
      "jpg"
    end

    def cmd(lines)
      puts "```"
      lines.each do |line|
        puts detab(line)
      end
      puts "```"
    end

    def table(lines, id = nil, caption = nil)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        table_header id, caption unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      table_begin rows.first.size
      return if rows.empty?
      if sepidx
        sepidx.times do
          tr rows.shift.map {|s| th(s) }
        end
        table_border rows.first.size
        rows.each do |cols|
          tr cols.map {|s| td(s) }
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr [th(h)] + cs.map {|s| td(s) }
        end
      end
      table_end
    end

    def table_header(id, caption)
      if get_chap.nil?
        puts %Q[#{I18n.t("table")}#{I18n.t("format_number_header_without_chapter", [@chapter.table(id).number])}#{I18n.t("caption_prefix")}#{compile_inline(caption)}]
      else
        puts %Q[#{I18n.t("table")}#{I18n.t("format_number_header", [get_chap, @chapter.table(id).number])}#{I18n.t("caption_prefix")}#{compile_inline(caption)}]
      end
      blank
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts "|#{rows.join("|")}|"
    end

    def table_border(ncols)
      puts (0..ncols).map{"|"}.join(":--")
    end

    def th(str)
      "#{str}"
    end

    def td(str)
      "#{str}"
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

    def inline_br(str)
      "\n"
    end

    def nofunc_text(str)
      str
    end
  end

end   # module ReVIEW
