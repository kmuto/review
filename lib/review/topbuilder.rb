# -*- encoding: euc-jp -*-
#
# $Id: topbuilder.rb 4304 2009-07-01 12:03:39Z kmuto $
#
# Copyright (c) 2002-2006 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
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

    [:i, :tt, :ttbold, :tti, :idx, :hidx, :dtp, :sup, :sub, :hint, :raw, :maru, :keytop, :labelref, :ref, :pageref, :u, :icon, :balloon].each {|e|
      Compiler.definline(e)
    }
    Compiler.defsingle(:dtp, 1)
    Compiler.defsingle(:raw, 1)
    Compiler.defsingle(:indepimage, 1)
    Compiler.defsingle(:label, 1)
    Compiler.defsingle(:tsize, 1)

    Compiler.defblock(:insn, 1)
    Compiler.defblock(:flushright, 0)
    Compiler.defblock(:note, 0..1)
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
    Compiler.defblock(:box, 0..1)
    Compiler.defblock(:expert, 0)
    Compiler.defblock(:lead, 0)

    def builder_init_file
      @section = 0
      @blank_seen = true
      @choice = nil
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
      # FIXME: handling label
      blank
      case level
      when 1
        puts "■H1■第#{@chapter.number}章　#{caption}"
      when 2
        puts "■H2■#{@chapter.number}.#{@section += 1}　#{caption}"
      when 3
        puts "■H3■#{caption}"
      when 4
        puts "■H4■#{caption}"
      when 5
        puts "■H5■#{caption}"
      else
        raise "caption level too deep or unsupported: #{level}"
      end
    end

    def column_begin(level, label, caption)
      blank
      puts "◆→開始:コラム←◆"
      puts "■#{caption}"
    end

    def column_end(level)
      puts "◆→終了:コラム←◆"
      blank
    end

    def ul_begin
      blank
    end

    def ul_item(lines)
      print @choice.nil? ? "●" : @choice
      puts "\t#{lines.join('')}"
    end

    def ul_end
      blank
    end

    def choice_single_begin
      @choice = "○"
      blank
    end

    def choice_single_end
      @choice = nil
      blank
    end

    def choice_multi_begin
      @choice = "□"
      blank
    end

    def choice_multi_end
      @choice = nil
      blank
    end

    def ol_begin
      blank
      @olitem = 0
    end

    def ol_item(lines, num)
      #puts "#{@olitem += 1}\t#{lines.join('')}"
      puts "#{num}\t#{lines.join('')}"
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

    def split_paragraph(lines)
      lines.map {|line| line.strip }.join("\n").strip.split("\n\n")
    end

    def dl_end
      blank
    end

    def paragraph(lines)
      puts lines.join('')
    end

    def read(lines)
      puts "◆→開始:リード←◆"
      paragraph(lines)
      puts "◆→終了:リード←◆"
    end

    alias lead read

    def inline_list(id)
      "リスト#{@chapter.number}.#{@chapter.list(id).number}"
    end

    def list_header(id, caption)
      blank
      puts "◆→開始:リスト←◆"
      puts "リスト#{@chapter.number}.#{@chapter.list(id).number}　#{caption}"
      blank
    end

    def list_body(lines)
      lines.each do |line|
        puts line
      end
      puts "◆→終了:リスト←◆"
      blank
    end

    def base_block(type, lines, caption = nil)
      blank
      puts "◆→開始:#{type}←◆"
      puts "■#{caption}" unless caption.nil?
      puts lines.join("\n")
      puts "◆→終了:#{type}←◆"
      blank
    end

    def emlist(lines, caption = nil)
      base_block "インラインリスト", lines, caption
    end

    def cmd(lines, caption = nil)
      base_block "コマンド", lines, caption
    end

    def quote(lines)
      base_block "引用", lines, nil
    end

    def inline_img(id)
      "図#{@chapter.number}.#{@chapter.image(id).number}"
    end

    def image(lines, id, caption)
      blank
      puts "◆→開始:図←◆"
      puts "図#{@chapter.number}.#{@chapter.image(id).number}　#{caption}"
      blank
      if @chapter.image(id).bound?
        puts "◆→#{@chapter.image(id).path}←◆"
      else
        lines.each do |line|
          puts line
        end
      end
      puts "◆→終了:図←◆"
      blank
    end

    def inline_table(id)
      "表#{@chapter.number}.#{@chapter.table(id).number}"
    end

    def table_header(id, caption)
      blank
      puts "◆→開始:表←◆"
      puts "表#{@chapter.number}.#{@chapter.table(id).number}　#{caption}"
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
      puts "◆→終了:表←◆"
      blank
    end

    def comment(str)
      puts "◆→DTP担当様:#{str}←◆"
    end

    def inline_fn(id)
      "【注#{@chapter.footnote(id).number}】"
    end

    def footnote(id, str)
      puts "【注#{@chapter.footnote(id).number}】#{compile_inline(str)}"
    end

    def compile_kw(word, alt)
      if alt
      then "★#{word}☆（#{alt.sub(/\A\s+/,"")}）"
      else "★#{word}☆"
      end
    end

    def inline_chap(id)
      #"「第#{super}章　#{inline_title(id)}」"
      # "第#{super}章"
      super
    end

    def compile_ruby(base, ruby)
      "#{base}◆→DTP担当様:「#{base}」に「#{ruby}」とルビ←◆"
    end

    def inline_bou(str)
      "#{str}◆→DTP担当様:「#{str}」に傍点←◆"
    end

    def inline_i(str)
      "▲#{str}☆"
    end

    def inline_b(str)
      "★#{str}☆"
    end

    def inline_tt(str)
      "△#{str}☆"
    end

    def inline_ttbold(str)
      "★#{str}☆◆→等幅フォント←◆"
    end

    def inline_ttibold(str)
      "▲#{str}☆◆→等幅フォント←◆"
    end

    def inline_u(str)
      "＠#{str}＠◆→＠〜＠部分に下線←◆"
    end

    def inline_icon(id)
      "◆→画像 #{@chapter.id}-#{id}.eps←◆"
    end

    def inline_ami(str)
      "#{str}◆→DTP担当様:「#{str}」に網カケ←◆"
    end

    def inline_sup(str)
      "#{str}◆→DTP担当様:「#{str}」は上付き←◆"
    end

    def inline_sub(str)
      "#{str}◆→DTP担当様:「#{str}」は下付き←◆"
    end

    def inline_raw(str)
      # FIXME
      str
    end

    def inline_hint(str)
      "◆→ヒントスタイル←◆#{str}"
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

    def inline_keytop(str)
      "#{str}◆→キートップ#{str}←◆"
    end

    def inline_labelref(idref)
      %Q(「◆→#{idref}←◆」) # 節、項を参照
    end

    alias inline_ref inline_labelref

    def inline_pageref(idref)
      %Q(●ページ◆→#{idref}←◆) # ページ番号を参照
    end

    def inline_balloon(str)
      %Q(\t←#{str.gsub(/@maru\[(\d+)\]/, inline_maru('\1'))})
    end

    def noindent
      %Q(◆→インデントなし←◆)
    end

    def nonum_begin(level, label, caption)
      puts "■H#{level}■#{caption}"
    end

    def nonum_end(level)
    end

    def circle_begin(level, label, caption)
      puts "・\t#{caption}"
    end

    def circle_end(level)
    end

    def flushright(lines)
      base_block "右寄せ", lines, nil
    end

    def note(lines, caption = nil)
      base_block "ノート", lines, caption
    end

    def memo(lines, caption = nil)
      base_block "メモ", lines, caption
    end

    def tip(lines, caption = nil)
      base_block "TIP", lines, caption
    end

    def info(lines, caption = nil)
      base_block "情報", lines, caption
    end

    def planning(lines, caption = nil)
      base_block "プランニング", lines, caption
    end

    def best(lines, caption = nil)
      base_block "ベストプラクティス", lines, caption
    end

    def important(lines, caption = nil)
      base_block "重要", lines, caption
    end

    def security(lines, caption = nil)
      base_block "セキュリティ", lines, caption
    end

    def caution(lines, caption = nil)
      base_block "警告", lines, caption
    end

    def term(lines)
      base_block "用語解説", lines, nil
    end

    def notice(lines, caption = nil)
      base_block "注意", lines, caption
    end

    def point(lines, caption = nil)
      base_block "ここがポイント", lines, caption
    end

    def reference(lines)
      base_block "参考", lines, nil
    end

    def practice(lines)
      base_block "練習問題", lines, nil
    end

    def expert(lines)
      base_block "エキスパートに訊け", lines, nil
    end

    def insn(lines, caption = nil)
      base_block "書式", lines, caption
    end

    alias box insn

    def indepimage(id)
      puts "◆→画像 #{@chapter.id}-#{id}.eps←◆"
    end

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

    def inline_dtp(str)
      # FIXME
      ""
    end
    
    def raw(str)
      if str =~ /\A<\/(.+)>$/
        case $1
          when "emlist": puts "◆→終了:インラインリスト←◆"
          when "cmd": puts "◆→終了:コマンド←◆"
          when "quote": puts "◆→終了:引用←◆"
          when "flushright": puts "◆→終了:右寄せ←◆"
          when "note": puts "◆→終了:ノート←◆"
          when "important": puts "◆→終了:重要←◆"
          when "term": puts "◆→終了:用語解説←◆"
          when "notice": puts "◆→終了:注意←◆"
          when "point": puts "◆→終了:ここがポイント←◆"
          when "reference": puts "◆→終了:参考←◆"
          when "practice": puts "◆→終了:練習問題←◆"
          when "expert": puts "◆→終了:エキスパートに訊け←◆"
          when "box": puts "◆→終了:書式←◆"
          when "insn": puts "◆→終了:書式←◆"
        end
      elsif str =~ /\A<([^\/].+)>(?:<title[^>]>(.+)<\/title>)?(.*)/
        case $1
          when "emlist": puts "◆→開始:インラインリスト←◆"
          when "cmd": puts "◆→開始:コマンド←◆"
          when "quote": puts "◆→開始:引用←◆"
          when "flushright": puts "◆→開始:右寄せ←◆"
          when "note": puts "◆→開始:ノート←◆"
          when "important": puts "◆→開始:重要←◆"
          when "term": puts "◆→開始:用語解説←◆"
          when "notice": puts "◆→開始:注意←◆"
          when "point": puts "◆→開始:ここがポイント←◆"
          when "reference": puts "◆→開始:参考←◆"
          when "practice": puts "◆→開始:練習問題←◆"
          when "expert": puts "◆→開始:エキスパートに訊け←◆"
          when "box": puts "◆→開始:書式←◆"
          when "insn": puts "◆→開始:書式←◆"
        end
        puts "■#{$2}" unless $2.nil?
        print $3
      else
        puts str
      end
    end
    
    def text(str)
      str
    end
    
    def nofunc_text(str)
      str
    end

  end

end   # module ReVIEW
