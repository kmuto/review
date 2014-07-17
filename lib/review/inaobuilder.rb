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
      buf = ""
      buf << "◆#{@titles[type]}/◆\n"
      buf << "■■■■■#{caption}\n" unless caption.nil?
      buf << split_paragraph(lines).join("\n") << "\n"
      buf << "◆/#{@titles[type]}◆\n"
      buf << "\n"
      buf
    end

    def headline(level, label, caption)
      prefix = "■" * level
      "#{prefix}#{caption}\n"
    end

    def paragraph(lines)
      buf = ""
      buf << "　" if @noindent.nil?
      @noindent = nil
      buf << lines.join + "\n"
      buf
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
      ""
    end

    def inline_fn(id)
      "◆注/◆#{@chapter.footnote(id).content.strip}◆/注◆"
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
      buf = ""
      buf << "◆column/◆\n"
      buf << "■■■■#{caption}\n"
      buf
    end

    def column_end(level)
      "◆/column◆\n"
    end

    def ul_begin
      ""
    end

    def ul_item(lines)
      "・#{lines.join}\n"
    end

    def ul_end
      ""
    end

    def ol_begin
      @olitem = 0
      ""
    end

    def ol_item(lines, num)
      "（#{num}）#{lines.join}\n"
    end

    def ol_end
      @olitem = nil
      ""
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
      buf = "◆list/◆\n"
      if get_chap.nil?
        buf << %Q[●リスト#{@chapter.list(id).number}　#{caption}\n]
      else
        buf << %Q[●リスト#{get_chap}.#{@chapter.list(id).number}　#{caption}\n]
      end
      buf
    end

    def list_body(id, lines)
      buf = ""
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << "◆/list◆\n"
      buf
    end

    def listnum_body(lines)
      buf = ""
      lines.each_with_index do |line, i|
        buf << detab((i+1).to_s.rjust(2) + " " +line) << "\n"
      end
      buf << "◆/list◆\n"
      buf
    end

    def emlist(lines, caption=nil)
      buf = ""
      buf << "◆list/◆\n"
      buf << %Q[●#{caption}\n] unless caption.nil?
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << "◆/list◆\n"
      buf
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
      buf = "◆list-white/◆\n"
      buf << %Q[●#{caption}\n] unless caption.nil?
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << "◆/list-white◆\n"
      buf
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
      buf = ""
      if get_chap.nil?
        buf << "●図#{@chapter.image(id).number}　#{caption}\n"
      else
        buf << "●図#{get_chap}.#{@chapter.image(id).number}　#{caption}\n"
      end
      if @chapter.image(id).bound?
        buf << @chapter.image(id).path << "\n"
      else
        lines.each do |line|
          buf << line << "\n"
        end
      end
      buf
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
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      buf << "◆table/◆\n"
      begin
        buf << table_header(id, caption) unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      return buf if rows.empty?
      buf << table_begin(rows.first.size)
      if sepidx
        sepidx.times do
          buf << "◆table-title◆"
          buf << tr(rows.shift.map {|s| th(s) })
        end
        rows.each do |cols|
          buf << tr(cols.map {|s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          buf << tr([th(h)] + cs.map {|s| td(s) })
        end
      end
      buf << table_end
      buf
    end

    def table_header(id, caption)
      if get_chap.nil?
        "●表#{@chapter.table(id).number}　#{caption}\n"
      else
        "●表#{get_chap}.#{@chapter.table(id).number}　#{caption}\n"
      end
    end

    def table_begin(ncols)
      ""
    end

    def tr(rows)
      rows.join("\t") + "\n"
    end

    def th(str)
      str
    end

    def td(str)
      str
    end

    def table_end
      "◆/table◆\n"
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
