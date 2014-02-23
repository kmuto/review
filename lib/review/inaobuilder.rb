# encoding: utf-8
#
# Copyright (c) 2012 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
# INAO Style (experimental)

require 'review/builder'
require 'review/textutils'

module ReVIEW

  class INAOBuilder < Builder

    include TextUtils

    def pre_paragraph
      ''
    end

    def post_paragraph
      ''
    end

    def extname
      '.txt'
    end

    def builder_init_file
      @blank_seen = true
      @noindent = nil

      @titles = {
        "emlist" => "list",
        "list" => "list",
        "cmd" => "list",
        "source" => "list",
        "quote" => "quote",
        "column" => "column",
      }
    end
    private :builder_init_file

    def print(s)
      @blank_seen = false
      super
    end
    private :print

    def puts(s)
      @blank_seen = false
      super
    end
    private :puts

    def blank
      @output.puts unless @blank_seen
      @blank_seen = true
    end
    private :blank

    def result
      @output.string
    end

    def warn(msg)
      $stderr.puts "#{@location.filename}:#{@location.lineno}: warning: #{msg}"
    end

    def error(msg)
      $stderr.puts "#{@location.filename}:#{@location.lineno}: error: #{msg}"
    end

    def messages
      error_messages() + warning_messages()
    end

    def base_parablock(type, lines, caption=nil)
      puts "◆#{@titles[type]}/◆"
      puts "■■■■■#{compile_inline(caption)}" unless caption.nil?
      puts split_paragraph(lines).join("\n")
      puts "◆/#{@titles[type]}◆"
      blank
    end

    def headline(level, label, caption)
      prefix = "■" * level
      puts "#{prefix}#{compile_inline(caption)}"
    end

    def paragraph(lines)
      print "　" if @noindent.nil?
      @noindent = nil
      puts lines.join
    end

    def noindent
      @noindent = true
    end

    def inline_b(str)
      "◆b/◆#{str}◆/b◆"
    end

    def inline_i(str)
      "◆i/◆#{str}◆/i◆"
    end

    def inline_tt(str)
      "◆cmd/◆#{str}◆/cmd◆"
    end

    def inline_cmd(str)
      inline_tt(str)
    end

    def footnote(id, str)
      #
    end

    def inline_fn(id)
      "◆注/◆#{compile_inline(@chapter.footnote(id).content.strip)}◆/注◆"
    end

    def inline_keytop(str)
      "#{str}▲"
    end

    def inline_kbd(str)
      inline_keytop(str)
    end

    # 「赤文字」はなし

    def compile_ruby(base, ruby)
      "◆ルビ/◆#{base}◆#{ruby}◆/ルビ◆"
    end

    def quote(lines)
      base_parablock "quote", lines, nil
    end

    def column_begin(level, label, caption)
      puts "◆column/◆"
      puts "■■■■#{compile_inline(caption)}"

    end

    def column_end(level)
      puts "◆/column◆"
    end

    def ul_begin
    end

    def ul_item(lines)
      puts "・#{lines.join}"
    end

    def ul_end
    end

    def ol_begin
      @olitem = 0
    end

    def ol_item(lines, num)
      puts "（#{num}）#{lines.join}"
    end

    def ol_end
      @olitem = nil
    end

    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        %Q[リスト#{@chapter.list(id).number}]
      else
        %Q[リスト#{get_chap(chapter)}.#{@chapter.list(id).number}]
      end
    end

    def list_header(id, caption)
      puts "◆list/◆"
      if get_chap.nil?
        puts %Q[●リスト#{@chapter.list(id).number}　#{compile_inline(caption)}]
      else
        puts %Q[●リスト#{get_chap}.#{@chapter.list(id).number}　#{compile_inline(caption)}]
      end
    end

    def list_body(id, lines)
      lines.each do |line|
        puts detab(line)
      end
      puts "◆/list◆"
    end

    def listnum_body(lines)
      lines.each_with_index do |line, i|
        puts detab((i+1).to_s.rjust(2) + " " +line)
      end
      puts "◆/list◆"
    end

    def emlist(lines, caption=nil)
      puts "◆list/◆"
      puts %Q[●#{compile_inline(caption)}] unless caption.nil?
      lines.each do |line|
        puts detab(line)
      end
      puts "◆/list◆"
    end

    # o1,o2のようなことはできない

    def inline_balloon(str)
      "◆comment/◆#{str}◆/comment◆"
    end

    def inline_comment(str)
      inline_balloon(str)
    end

    # whiteリスト代用
    def cmd(lines, caption=nil)
      puts "◆list-white/◆"
      puts %Q[●#{compile_inline(caption)}] unless caption.nil?
      lines.each do |line|
        puts detab(line)
      end
      puts "◆/list-white◆"
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "図#{chapter.image(id).number}"
      else
        "図#{get_chap(chapter)}.#{chapter.image(id).number}"
      end
    end

    def image(lines, id, caption, metric=nil)
      if get_chap.nil?
        puts "●図#{@chapter.image(id).number}　#{compile_inline(caption)}"
      else
        puts "●図#{get_chap}.#{@chapter.image(id).number}　#{compile_inline(caption)}"
      end
      if @chapter.image(id).bound?
        puts @chapter.image(id).path
      else
        lines.each do |line|
          puts line
        end
      end
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "表#{chapter.table(id).number}"
      else
        "表#{get_chap(chapter)}.#{chapter.table(id).number}"
      end
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

      puts "◆table/◆"
      begin
        table_header id, caption unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      return if rows.empty?
      table_begin rows.first.size
      if sepidx
        sepidx.times do
          print "◆table-title◆"
          tr rows.shift.map {|s| th(s) }
        end
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
        puts "●表#{@chapter.table(id).number}　#{compile_inline(caption)}"
      else
        puts "●表#{get_chap}.#{@chapter.table(id).number}　#{compile_inline(caption)}"
      end
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts rows.join("\t")
    end

    def th(str)
      str
    end

    def td(str)
      str
    end

    def table_end
      puts "◆/table◆"
    end

    def inline_raw(str)
      %Q[#{super(str).gsub("\\n", "\n")}]
    end

    def inline_uchar(str)
      [str.to_i(16)].pack("U")
    end

    def text(str)
      str
    end

    def nofunc_text(str)
      str
    end
  end

end   # module ReVIEW
