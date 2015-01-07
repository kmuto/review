# encoding: utf-8
#
# Copyright (c) 2002-2006 Minero Aoki
#               2008-2010 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/textutils'

module ReVIEW

  class TOPBuilder < Builder

    include TextUtils

    [:ttbold, :hint, :maru, :keytop, :labelref, :ref, :pageref, :balloon, :strong].each {|e|
      Compiler.definline(e)
    }
    Compiler.defsingle(:dtp, 1)

    Compiler.defblock(:insn, 1)
    Compiler.defblock(:memo, 0..1)
    Compiler.defblock(:tip, 0..1)
    Compiler.defblock(:info, 0..1)
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:important, 0..1)
    Compiler.defblock(:securty, 0..1)
    Compiler.defblock(:caution, 0..1)
    Compiler.defblock(:notice, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:reference, 0)
    Compiler.defblock(:term, 0)
    Compiler.defblock(:practice, 0)
    Compiler.defblock(:expert, 0)

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
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
      @blank_seen = true

      @titles = {
        "emlist" => "インラインリスト",
        "cmd" => "コマンド",
        "quote" => "引用",
        "centering" => "中央揃え",
        "flushright" => "右寄せ",
        "note" => "ノート",
        "memo" => "メモ",
        "important" => "重要",
        "info" => "情報",
        "planning" => "プランニング",
        "shoot" => "トラブルシュート",
        "term" => "用語解説",
        "notice" => "注意",
        "caution" => "警告",
        "point" => "ここがポイント",
        "reference" => "参考",
        "link" => "リンク",
        "best" => "ベストプラクティス",
        "practice" => "練習問題",
        "security" => "セキュリティ",
        "expert" => "エキスパートに訊け",
        "tip" => "TIP",
        "box" => "書式",
        "insn" => "書式",
        "column" => "コラム",
        "xcolumn" => "コラムパターン2",
        "world" => "Worldコラム",
        "hood" => "Under The Hoodコラム",
        "edition" => "Editionコラム",
        "insideout" => "InSideOutコラム",
        "ref" => "参照",
        "sup" => "補足",
        "read" => "リード",
        "lead" => "リード",
        "list" => "リスト",
        "image" => "図",
        "texequation" => "TeX式",
        "table" => "表",
        "bpo" => "bpo",
        "source" => "ソースコードリスト",
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

    def headline(level, label, caption)
      prefix = ""
      blank
      case level
      when 1
        if @chapter.number.to_s =~ /\A\d+\Z/
          prefix = "第#{@chapter.number}章　"
        elsif @chapter.number.present?
          prefix = "#{@chapter.number}　"
        end
        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 2
        @section += 1
        prefix = @chapter.number.present? ? "#{@chapter.number}.#{@section}　" : ""
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 3
        @subsection += 1
        prefix = @chapter.number.present? ? "#{@chapter.number}.#{@section}.#{@subsection}　" : ""
        @subsubsection = 0
        @subsubsubsection = 0
      when 4
        @subsubsection += 1
        prefix = @chapter.number.present? ? "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}　" : ""
        @subsubsubsection = 0
      when 5
        @subsubsubsection += 1
        prefix = @chapter.number.present? ? "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}　" : ""
      else
        raise "caption level too deep or unsupported: #{level}"
      end
      prefix = "" if (level.to_i > @book.config["secnolevel"])
      puts "■H#{level}■#{prefix}#{compile_inline(caption)}"
    end

    def ul_begin
      blank
    end

    def ul_item(lines)
      puts "●\t#{lines.join}"
    end

    def ul_end
      blank
    end

    def ol_begin
      blank
      @olitem = 0
    end

    def ol_item(lines, num)
      puts "#{num}\t#{lines.join}"
    end

    def ol_end
      blank
      @olitem = nil
    end

    def dl_begin
      blank
    end

    def dt(line)
      puts "★#{line}☆"
    end

    def dd(lines)
      split_paragraph(lines).each do |paragraph|
        puts "\t#{paragraph.gsub(/\n/, '')}"
      end
    end

    def dl_end
      blank
    end

    def paragraph(lines)
      puts lines.join
    end

    def read(lines)
      puts "◆→開始:#{@titles["lead"]}←◆"
      puts split_paragraph(lines).join("\n")
      puts "◆→終了:#{@titles["lead"]}←◆"
      blank
    end

    alias_method :lead, :read

    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        %Q[#{I18n.t("list")}#{I18n.t("format_number_without_chapter", [@chapter.list(id).number])}]
      else
        %Q[#{I18n.t("list")}#{I18n.t("format_number", [get_chap(chapter), @chapter.list(id).number])}]
      end

    end

    def list_header(id, caption)
      blank
      puts "◆→開始:#{@titles["list"]}←◆"
      if get_chap.nil?
        puts %Q[#{I18n.t("list")}#{I18n.t("format_number_without_chapter", [@chapter.list(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}]
      else
        puts %Q[#{I18n.t("list")}#{I18n.t("format_number", [get_chap, @chapter.list(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}]
      end
      blank
    end

    def list_body(id, lines)
      lines.each do |line|
        puts detab(line)
      end
      puts "◆→終了:#{@titles["list"]}←◆"
      blank
    end

    def base_block(type, lines, caption = nil)
      blank
      puts "◆→開始:#{@titles[type]}←◆"
      puts "■#{compile_inline(caption)}" unless caption.nil?
      puts lines.join("\n")
      puts "◆→終了:#{@titles[type]}←◆"
      blank
    end

    def base_parablock(type, lines, caption = nil)
      blank
      puts "◆→開始:#{@titles[type]}←◆"
      puts "■#{compile_inline(caption)}" unless caption.nil?
      puts split_paragraph(lines).join("\n")
      puts "◆→終了:#{@titles[type]}←◆"
      blank
    end

    def emlist(lines, caption = nil)
      base_block "emlist", lines, caption
    end

    def emlistnum(lines, caption = nil)
      blank
      puts "◆→開始:#{@titles["emlist"]}←◆"
      puts "■#{compile_inline(caption)}" unless caption.nil?
      _lines = []
      lines.each_with_index do |line, i|
        puts (i + 1).to_s.rjust(2) + ": #{line}"
      end
      puts "◆→終了:#{@titles["emlist"]}←◆"
      blank
    end

    def listnum_body(lines)
      lines.each_with_index do |line, i|
        puts (i + 1).to_s.rjust(2) + ": #{line}"
      end
      puts "◆→終了:#{@titles["list"]}←◆"
      blank
    end

    def cmd(lines, caption = nil)
      base_block "cmd", lines, caption
    end

    def quote(lines)
      base_parablock "quote", lines, nil
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "#{I18n.t("table")}#{I18n.t("format_number_without_chapter", [chapter.table(id).number])}"
      else
        "#{I18n.t("table")}#{I18n.t("format_number", [get_chap(chapter), chapter.table(id).number])}"
      end
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        "#{I18n.t("image")}#{I18n.t("format_number_without_chapter", [chapter.image(id).number])}"
      else
        "#{I18n.t("image")}#{I18n.t("format_number", [get_chap(chapter), chapter.image(id).number])}"
      end
    end

    def image(lines, id, caption, metric=nil)
      blank
      puts "◆→開始:#{@titles["image"]}←◆"
      if get_chap.nil?
        puts "#{I18n.t("image")}#{I18n.t("format_number_without_chapter", [@chapter.image(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}"
      else
        puts "#{I18n.t("image")}#{I18n.t("format_number", [get_chap, @chapter.image(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}"
      end
      blank
      if @chapter.image(id).bound?
        puts "◆→#{@chapter.image(id).path}←◆"
      else
        lines.each do |line|
          puts line
        end
      end
      puts "◆→終了:#{@titles["image"]}←◆"
      blank
    end

    def texequation(lines)
      puts "◆→開始:#{@titles["texequation"]}←◆"
      puts "#{lines.join("\n")}"
      puts "◆→終了:#{@titles["texequation"]}←◆"
      blank
    end

    def table_header(id, caption)
      blank
      puts "◆→開始:#{@titles["table"]}←◆"
      if get_chap.nil?
        puts "#{I18n.t("table")}#{I18n.t("format_number_without_chapter", [@chapter.table(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}"
      else
        puts "#{I18n.t("table")}#{I18n.t("format_number", [get_chap, @chapter.table(id).number])}#{I18n.t("caption_prefix_idgxml")}#{compile_inline(caption)}"
      end
      blank
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts rows.join("\t")
    end

    def th(str)
      "★#{str}☆"
    end

    def td(str)
      str
    end

    def table_end
      puts "◆→終了:#{@titles["table"]}←◆"
      blank
    end

    def comment(lines, comment = nil)
      lines ||= []
      lines.unshift comment unless comment.blank?
      str = lines.join("")
      puts "◆→DTP連絡:#{str}←◆"
    end

    def footnote(id, str)
      puts "【注#{@chapter.footnote(id).number}】#{compile_inline(str)}"
    end

    def inline_fn(id)
      "【注#{@chapter.footnote(id).number}】"
    end

    def compile_ruby(base, ruby)
      "#{base}◆→DTP連絡:「#{base}」に「#{ruby}」とルビ←◆"
    end

    def compile_kw(word, alt)
      if alt
      then "★#{word}☆（#{alt.strip}）"
      else "★#{word}☆"
      end
    end

    def compile_href(url, label)
      if label.nil?
        %Q[△#{url}☆]
      else
        %Q[#{label}（△#{url}☆）]
      end
    end

    def inline_sup(str)
      "#{str}◆→DTP連絡:「#{str}」は上付き←◆"
    end

    def inline_sub(str)
      "#{str}◆→DTP連絡:「#{str}」は下付き←◆"
    end

    def inline_raw(str)
      %Q[#{super(str).gsub("\\n", "\n")}]
    end

    def inline_hint(str)
      "◆→ヒントスタイルここから←◆#{str}◆→ヒントスタイルここまで←◆"
    end

    def inline_maru(str)
      "#{str}◆→丸数字#{str}←◆"
    end

    def inline_idx(str)
      "#{str}◆→索引項目:#{str}←◆"
    end

    def inline_hidx(str)
      "◆→索引項目:#{str}←◆"
    end

    def inline_ami(str)
      "#{str}◆→DTP連絡:「#{str}」に網カケ←◆"
    end

    def inline_i(str)
      "▲#{str}☆"
    end

    def inline_b(str)
      "★#{str}☆"
    end

    alias_method :inline_strong, :inline_b

    def inline_tt(str)
      "△#{str}☆"
    end

    def inline_ttb(str)
      "★#{str}☆◆→等幅フォント太字←◆"
    end

    alias_method :inline_ttbold, :inline_ttb

    def inline_tti(str)
      "▲#{str}☆◆→等幅フォントイタ←◆"
    end

    def inline_u(str)
      "＠#{str}＠◆→＠〜＠部分に下線←◆"
    end

    def inline_icon(id)
      begin
        return "◆→画像 #{@chapter.image(id).path.sub(/\A\.\//, "")}←◆"
      rescue
        warn "no such icon image: #{id}"
        return "◆→画像 #{id}←◆"
      end
    end

    def inline_bou(str)
      "#{str}◆→DTP連絡:「#{str}」に傍点←◆"
    end

    def inline_keytop(str)
      "#{str}◆→キートップ#{str}←◆"
    end

    def inline_balloon(str)
      %Q(\t←#{str.gsub(/@maru\[(\d+)\]/, inline_maru('\1'))})
    end

    def inline_uchar(str)
      [str.to_i(16)].pack("U")
    end

    def inline_m(str)
      %Q[◆→TeX式ここから←◆#{str}◆→TeX式ここまで←◆]
    end

    def noindent
      puts "◆→DTP連絡:次の1行インデントなし←◆"
    end

    def nonum_begin(level, label, caption)
      puts "■H#{level}■#{compile_inline(caption)}"
    end

    def nonum_end(level)
    end

    def common_column_begin(type, caption)
      blank
      puts "◆→開始:#{@titles[type]}←◆"
      puts %Q[■#{compile_inline(caption)}]
    end

    def common_column_end(type)
      puts %Q[◆→終了:#{@titles[type]}←◆]
      blank
    end

    def column_begin(level, label, caption)
      common_column_begin("column", caption)
    end

    def column_end(level)
      common_column_end("column")
    end

    def xcolumn_begin(level, label, caption)
      common_column_begin("xcolumn", caption)
    end

    def xcolumn_end(level)
      common_column_end("xcolumn")
    end

    def world_begin(level, label, caption)
      common_column_begin("world", caption)
    end

    def world_end(level)
      common_column_end("world")
    end

    def hood_begin(level, label, caption)
      common_column_begin("hood", caption)
    end

    def hood_end(level)
      common_column_end("hood")
    end

    def edition_begin(level, label, caption)
      common_column_begin("edition", caption)
    end

    def edition_end(level)
      common_column_end("edition")
    end

    def insideout_begin(level, label, caption)
      common_column_begin("insideout", caption)
    end

    def insideout_end(level)
      common_column_end("insideout")
    end

    def ref_begin(level, label, caption)
      common_column_begin("ref", caption)
    end

    def ref_end(level)
      common_column_end("ref")
    end

    def sup_begin(level, label, caption)
      common_column_begin("sup", caption)
    end

    def sup_end(level)
      common_column_end("sup")
    end

    def flushright(lines)
      base_parablock "flushright", lines, nil
    end

    def centering(lines)
      base_parablock "centering", lines, nil
    end

    def note(lines, caption = nil)
      base_parablock "note", lines, caption
    end

    def memo(lines, caption = nil)
      base_parablock "memo", lines, caption
    end

    def tip(lines, caption = nil)
      base_parablock "tip", lines, caption
    end

    def info(lines, caption = nil)
      base_parablock "info", lines, caption
    end

    def planning(lines, caption = nil)
      base_parablock "planning", lines, caption
    end

    def best(lines, caption = nil)
      base_parablock "best", lines, caption
    end

    def important(lines, caption = nil)
      base_parablock "important", lines, caption
    end

    def security(lines, caption = nil)
      base_parablock "security", lines, caption
    end

    def caution(lines, caption = nil)
      base_parablock "caution", lines, caption
    end

    def term(lines)
      base_parablock "term", lines, nil
    end

    def link(lines, caption = nil)
      base_parablock "link", lines, caption
    end

    def notice(lines, caption = nil)
      base_parablock "notice", lines, caption
    end

    def point(lines, caption = nil)
      base_parablock "point", lines, caption
    end

    def shoot(lines, caption = nil)
      base_parablock "shoot", lines, caption
    end

    def reference(lines)
      base_parablock "reference", lines, nil
    end

    def practice(lines)
      base_parablock "practice", lines, nil
    end

    def expert(lines)
      base_parablock "expert", lines, nil
    end

    def insn(lines, caption = nil)
      base_block "insn", lines, caption
    end

    alias_method :box, :insn

    def indepimage(id, caption=nil, metric=nil)
      blank
      begin
        puts "◆→画像 #{@chapter.image(id).path.sub(/\A\.\//, "")} #{metric.join(" ")}←◆"
      rescue
        warn "no such image: #{id}"
        puts "◆→画像 #{id}←◆"
      end
      puts "図　#{compile_inline(caption)}" if caption.present?
      blank
    end

    alias_method :numberlessimage, :indepimage

    def label(id)
      # FIXME
      ""
    end

    def tsize(id)
      # FIXME
      ""
    end

    def dtp(str)
      # FIXME
    end

    def bpo(lines)
      base_block "bpo", lines, nil
    end

    def inline_dtp(str)
      # FIXME
      ""
    end

    def inline_del(str)
      # FIXME
      ""
    end

    def inline_code(str)
      %Q[△#{str}☆]
    end

    def inline_br(str)
      %Q(\n)
    end

    def text(str)
      str
    end

    def inline_chap(id)
      #"「第#{super}章　#{inline_title(id)}」"
      # "第#{super}章"
      super
    end

    def inline_chapref(id)
      chs = ["", "「", "」"]
      unless @book.config["chapref"].nil?
        _chs = convert_inencoding(@book.config["chapref"],
                                  @book.config["inencoding"]).split(",")
        if _chs.size != 3
          error "--chapsplitter must have exactly 3 parameters with comma."
        else
          chs = _chs
        end
      else
      end
      "#{chs[0]}#{@book.chapter_index.number(id)}#{chs[1]}#{@book.chapter_index.title(id)}#{chs[2]}"
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def source(lines, caption = nil)
      base_block "source", lines, caption
    end

    def inline_ttibold(str)
      "▲#{str}☆◆→等幅フォント太字イタ←◆"
    end

    def inline_labelref(idref)
      %Q(「◆→#{idref}←◆」) # 節、項を参照
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      %Q(●ページ◆→#{idref}←◆) # ページ番号を参照
    end

    def circle_begin(level, label, caption)
      puts "・\t#{caption}"
    end

    def circle_end(level)
    end

    def nofunc_text(str)
      str
    end

  end

end   # module ReVIEW
