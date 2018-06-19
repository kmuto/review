# Copyright (c) 2008-2018 Minero Aoki, Kenshi Muto
#               2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/plaintextbuilder'

module ReVIEW
  class TOPBuilder < PLAINTEXTBuilder
    def builder_init_file
      super

      @titles = {
        'emlist' => 'インラインリスト',
        'cmd' => 'コマンド',
        'quote' => '引用',
        'centering' => '中央揃え',
        'flushright' => '右寄せ',
        'note' => 'ノート',
        'memo' => 'メモ',
        'important' => '重要',
        'info' => '情報',
        'planning' => 'プランニング',
        'shoot' => 'トラブルシュート',
        'term' => '用語解説',
        'notice' => '注意',
        'caution' => '警告',
        'warning' => '危険',
        'point' => 'ここがポイント',
        'reference' => '参考',
        'link' => 'リンク',
        'best' => 'ベストプラクティス',
        'practice' => '練習問題',
        'security' => 'セキュリティ',
        'expert' => 'エキスパートに訊け',
        'tip' => 'TIP',
        'box' => '書式',
        'insn' => '書式',
        'column' => 'コラム',
        'xcolumn' => 'コラムパターン2',
        'world' => 'Worldコラム',
        'hood' => 'Under The Hoodコラム',
        'edition' => 'Editionコラム',
        'insideout' => 'InSideOutコラム',
        'ref' => '参照',
        'sup' => '補足',
        'read' => 'リード',
        'lead' => 'リード',
        'list' => 'リスト',
        'image' => '図',
        'texequation' => 'TeX式',
        'table' => '表',
        'bpo' => 'bpo',
        'source' => 'ソースコードリスト'
      }
    end
    private :builder_init_file

    def headline(level, _label, caption)
      prefix, _anchor = headline_prefix(level)
      puts %Q(■H#{level}■#{prefix}#{compile_inline(caption)})
    end

    def ul_item(lines)
      puts "●\t#{lines.join}"
    end

    def ol_item(lines, num)
      puts "#{num}\t#{lines.join}"
    end

    def dt(line)
      puts "★#{line}☆"
    end

    def dd(lines)
      split_paragraph(lines).each do |paragraph|
        puts "\t#{paragraph.gsub(/\n/, '')}"
      end
    end

    def read(lines)
      puts "◆→開始:#{@titles['lead']}←◆"
      puts split_paragraph(lines).join("\n")
      puts "◆→終了:#{@titles['lead']}←◆"
      blank
    end

    alias_method :lead, :read

    def list_header(id, caption, _lang)
      blank
      puts "◆→開始:#{@titles['list']}←◆"
      if get_chap
        puts %Q(#{I18n.t('list')}#{I18n.t('format_number', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)})
      else
        puts %Q(#{I18n.t('list')}#{I18n.t('format_number_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)})
      end
      blank
    end

    def list_body(_id, lines, _lang)
      lines.each do |line|
        puts detab(line)
      end
      puts "◆→終了:#{@titles['list']}←◆"
      blank
    end

    def base_block(type, lines, caption = nil)
      blank
      puts "◆→開始:#{@titles[type]}←◆"
      puts "■#{compile_inline(caption)}" if caption.present?
      puts lines.join("\n")
      puts "◆→終了:#{@titles[type]}←◆"
      blank
    end

    def base_parablock(type, lines, caption = nil)
      blank
      puts "◆→開始:#{@titles[type]}←◆"
      puts "■#{compile_inline(caption)}" if caption.present?
      puts split_paragraph(lines).join("\n")
      puts "◆→終了:#{@titles[type]}←◆"
      blank
    end

    def emlistnum(lines, caption = nil, _lang = nil)
      blank
      puts "◆→開始:#{@titles['emlist']}←◆"
      puts "■#{compile_inline(caption)}" if caption.present?
      lines.each_with_index do |line, i|
        puts((i + 1).to_s.rjust(2) + ": #{line}")
      end
      puts "◆→終了:#{@titles['emlist']}←◆"
      blank
    end

    def listnum_body(lines, _lang)
      lines.each_with_index do |line, i|
        puts((i + 1).to_s.rjust(2) + ": #{line}")
      end
      puts "◆→終了:#{@titles['list']}←◆"
      blank
    end

    def image(lines, id, caption, metric = nil)
      metrics = parse_metric('top', metric)
      metrics = " #{metrics}" if metrics.present?
      blank
      puts "◆→開始:#{@titles['image']}←◆"
      if get_chap
        puts "#{I18n.t('image')}#{I18n.t('format_number', [get_chap, @chapter.image(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}"
      else
        puts "#{I18n.t('image')}#{I18n.t('format_number_without_chapter', [@chapter.image(id).number])}#{I18n.t('caption_prefix_idgxml')}#{compile_inline(caption)}"
      end
      blank
      if @chapter.image(id).bound?
        puts "◆→#{@chapter.image(id).path}#{metrics}←◆"
      else
        warn "image not bound: #{id}"
        lines.each do |line|
          puts line
        end
      end
      puts "◆→終了:#{@titles['image']}←◆"
      blank
    end

    def texequation(lines)
      puts "◆→開始:#{@titles['texequation']}←◆"
      puts lines.join("\n")
      puts "◆→終了:#{@titles['texequation']}←◆"
      blank
    end

    def table(lines, id = nil, caption = nil)
      blank
      puts "◆→開始:#{@titles['table']}←◆"

      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          # error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push(line.strip.split(/\t+/).map { |s| s.sub(/\A\./, '') })
      end
      rows = adjust_n_cols(rows)

      begin
        table_header id, caption if caption.present?
      rescue KeyError
        error "no such table: #{id}"
      end
      return if rows.empty?
      table_begin rows.first.size
      if sepidx
        sepidx.times do
          tr(rows.shift.map { |s| th(s) })
        end
        rows.each do |cols|
          tr(cols.map { |s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr([th(h)] + cs.map { |s| td(s) })
        end
      end
      table_end
    end

    def th(str)
      "★#{str}☆"
    end

    def table_end
      puts "◆→終了:#{@titles['table']}←◆"
      blank
    end

    def comment(lines, comment = nil)
      return unless @book.config['draft']
      lines ||= []
      unless comment.blank?
        lines.unshift comment
      end
      str = lines.join
      puts "◆→#{str}←◆"
    end

    def footnote(id, str)
      puts "【注#{@chapter.footnote(id).number}】#{compile_inline(str)}"
    end

    def inline_fn(id)
      "【注#{@chapter.footnote(id).number}】"
    rescue KeyError
      error "unknown footnote: #{id}"
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
      if label
        "#{label}（△#{url}☆）"
      else
        "△#{url}☆"
      end
    end

    def inline_sup(str)
      "#{str}◆→DTP連絡:「#{str}」は上付き←◆"
    end

    def inline_sub(str)
      "#{str}◆→DTP連絡:「#{str}」は下付き←◆"
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
        "◆→画像 #{@chapter.image(id).path.sub(%r{\A\./}, '')}←◆"
      rescue
        warn "image not bound: #{id}"
        "◆→画像 #{id}←◆"
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

    def inline_comment(str)
      if @book.config['draft']
        "◆→#{str}←◆"
      else
        ''
      end
    end

    def inline_m(str)
      %Q(◆→TeX式ここから←◆#{str}◆→TeX式ここまで←◆)
    end

    def bibpaper_header(id, caption)
      print "[#{@chapter.bibpaper(id).number}]"
      puts " #{compile_inline(caption)}"
    end

    def inline_bib(id)
      %Q([#{@chapter.bibpaper(id).number}])
    rescue KeyError
      error "unknown bib: #{id}"
    end

    def noindent
      puts '◆→DTP連絡:次の1行インデントなし←◆'
    end

    def nonum_begin(level, _label, caption)
      puts "■H#{level}■#{compile_inline(caption)}"
    end

    def notoc_begin(level, _label, caption)
      puts "■H#{level}■#{compile_inline(caption)}◆→DTP連絡:目次に掲載しない←◆"
    end

    def common_column_begin(type, caption)
      blank
      puts "◆→開始:#{@titles[type]}←◆"
      puts "■#{compile_inline(caption)}"
    end

    def common_column_end(type)
      puts "◆→終了:#{@titles[type]}←◆"
      blank
    end

    def indepimage(_lines, id, caption = nil, metric = nil)
      metrics = parse_metric('top', metric)
      metrics = " #{metrics}" if metrics.present?
      blank
      begin
        puts "◆→画像 #{@chapter.image(id).path.sub(%r{\A\./}, '')}#{metrics}←◆"
      rescue
        warn "image not bound: #{id}"
        puts "◆→画像 #{id}←◆"
      end
      puts "図　#{compile_inline(caption)}" if caption.present?
      blank
    end

    alias_method :numberlessimage, :indepimage

    def inline_code(str)
      "△#{str}☆"
    end

    def inline_ttibold(str)
      "▲#{str}☆◆→等幅フォント太字イタ←◆"
    end

    def inline_labelref(idref)
      "「◆→#{idref}←◆」" # 節、項を参照
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      "●ページ◆→#{idref}←◆" # ページ番号を参照
    end

    def circle_begin(_level, _label, caption)
      puts "・\t#{caption}"
    end
  end
end # module ReVIEW
