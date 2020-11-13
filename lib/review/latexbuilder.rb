# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
#               2010-2020 Minero Aoki, Kenshi Muto, TAKAHASHI Masayoshi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/builder'
require 'review/latexutils'
require 'review/textutils'

module ReVIEW
  class LATEXBuilder < Builder
    include LaTeXUtils
    include TextUtils

    %i[dtp hd_chap].each do |e|
      Compiler.definline(e)
    end

    Compiler.defsingle(:latextsize, 1)

    def extname
      '.tex'
    end

    def builder_init_file
      @chapter.book.image_types = %w[.ai .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif]
      @blank_needed = false
      @latex_tsize = nil
      @tsize = nil
      @cellwidth = nil
      @ol_num = nil
      @first_line_num = nil
      @sec_counter = SecCounter.new(5, @chapter)
      @foottext = {}
      setup_index
      initialize_metachars(@book.config['texcommand'])
    end
    private :builder_init_file

    def setup_index
      @index_db = {}
      @index_mecab = nil
      return true unless @book.config['pdfmaker']['makeindex']

      if @book.config['pdfmaker']['makeindex_dic']
        @index_db = load_idxdb(@book.config['pdfmaker']['makeindex_dic'])
      end
      return true unless @book.config['pdfmaker']['makeindex_mecab']
      begin
        begin
          require 'MeCab'
        rescue LoadError
          require 'mecab'
        end
        require 'nkf'
        @index_mecab = MeCab::Tagger.new(@book.config['pdfmaker']['makeindex_mecab_opts'])
      rescue LoadError
        warn 'not found MeCab'
      end
    end

    def load_idxdb(file)
      table = {}
      File.foreach(file) do |line|
        key, value = *line.strip.split(/\t+/, 2)
        table[key] = value
      end
      table
    end

    def blank
      @blank_needed = true
    end
    private :blank

    def print(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :print

    def puts(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :puts

    def result
      if @chapter.is_a?(ReVIEW::Book::Part) && !@book.config.check_version('2', exception: false)
        puts '\end{reviewpart}'
      end
      solve_nest(@output.string)
    end

    def solve_nest(s)
      check_nest
      s.gsub("\\end{description}\n\n\x01→dl←\x01\n", "\n").
        gsub("\x01→/dl←\x01", "\\end{description}←END\x01").
        gsub("\\end{itemize}\n\n\x01→ul←\x01\n", "\n").
        gsub("\x01→/ul←\x01", "\\end{itemize}←END\x01").
        gsub("\\end{enumerate}\n\n\x01→ol←\x01\n", "\n").
        gsub("\x01→/ol←\x01", "\\end{enumerate}←END\x01").
        gsub("\\end{description}←END\x01\n\n\\begin{description}", '').
        gsub("\\end{itemize}←END\x01\n\n\\begin{itemize}", '').
        gsub("\\end{enumerate}←END\x01\n\n\\begin{enumerate}", '').
        gsub("←END\x01", '')
    end

    HEADLINE = {
      1 => 'chapter',
      2 => 'section',
      3 => 'subsection',
      4 => 'subsubsection',
      5 => 'paragraph',
      6 => 'subparagraph'
    }.freeze

    def headline(level, label, caption)
      _, anchor = headline_prefix(level)
      headline_name = HEADLINE[level]
      if @chapter.is_a?(ReVIEW::Book::Part)
        if @book.config.check_version('2', exception: false)
          headline_name = 'part'
        elsif level == 1
          headline_name = 'part'
          puts '\begin{reviewpart}'
        end
      end
      prefix = ''
      if level > @book.config['secnolevel'] || (@chapter.number.to_s.empty? && level > 1)
        prefix = '*'
      end
      blank unless @output.pos == 0
      @doc_status[:caption] = true
      puts macro(headline_name + prefix, compile_inline(caption))
      @doc_status[:caption] = nil
      if prefix == '*' && level <= @book.config['toclevel'].to_i
        puts "\\addcontentsline{toc}{#{headline_name}}{#{compile_inline(caption)}}"
      end
      if level == 1
        puts macro('label', chapter_label)
      else
        puts macro('label', sec_label(anchor))
        puts macro('label', label) if label
      end
    rescue
      error "unknown level: #{level}"
    end

    def nonum_begin(level, _label, caption)
      blank unless @output.pos == 0
      @doc_status[:caption] = true
      puts macro(HEADLINE[level] + '*', compile_inline(caption))
      @doc_status[:caption] = nil
      puts macro('addcontentsline', 'toc', HEADLINE[level], compile_inline(caption))
    end

    def nonum_end(level)
    end

    def notoc_begin(level, _label, caption)
      blank unless @output.pos == 0
      @doc_status[:caption] = true
      puts macro(HEADLINE[level] + '*', compile_inline(caption))
      @doc_status[:caption] = nil
    end

    def notoc_end(level)
    end

    def nodisp_begin(level, _label, caption)
      if @output.pos == 0
        puts macro('clearpage')
      else
        blank
      end
      puts macro('addcontentsline', 'toc', HEADLINE[level], compile_inline(caption))
      # FIXME: headings
    end

    def nodisp_end(level)
    end

    def column_begin(level, label, caption)
      blank
      @doc_status[:column] = true

      target = nil
      if label
        target = "\\hypertarget{#{column_label(label)}}{}"
      else
        target = "\\hypertarget{#{column_label(caption)}}{}"
      end

      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        puts '\\begin{reviewcolumn}'
        puts target
        puts macro('reviewcolumnhead', nil, compile_inline(caption))
      else
        # ver.3
        print '\\begin{reviewcolumn}'
        puts "[#{compile_inline(caption)}#{target}]"
      end
      @doc_status[:caption] = nil

      if level <= @book.config['toclevel'].to_i
        puts "\\addcontentsline{toc}{#{HEADLINE[level]}}{#{compile_inline(caption)}}"
      end
    end

    def column_end(_level)
      puts '\\end{reviewcolumn}'
      blank
      @doc_status[:column] = nil
    end

    def common_block_begin(type, caption = nil)
      check_nested_minicolumn
      if @book.config.check_version('2', exception: false)
        type = 'minicolumn'
      end

      @doc_status[:minicolumn] = type
      print "\\begin{review#{type}}"

      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        puts
        if caption.present?
          puts "\\reviewminicolumntitle{#{compile_inline(caption)}}"
        end
      else
        if caption.present?
          print "[#{compile_inline(caption)}]"
        end
        puts
      end
      @doc_status[:caption] = nil
    end

    def common_block_end(type)
      if @book.config.check_version('2', exception: false)
        type = 'minicolumn'
      end

      puts "\\end{review#{type}}"
      @doc_status[:minicolumn] = nil
    end

    CAPTION_TITLES.each do |name|
      class_eval %Q(
        def #{name}_begin(caption = nil)
          common_block_begin('#{name}', caption)
        end

        def #{name}_end
          common_block_end('#{name}')
        end
      ), __FILE__, __LINE__ - 8
    end

    def captionblock(type, lines, caption)
      check_nested_minicolumn
      if @book.config.check_version('2', exception: false)
        type = 'minicolumn'
      end

      print "\\begin{review#{type}}"

      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        puts
        if caption.present?
          puts "\\reviewminicolumntitle{#{compile_inline(caption)}}"
        end
      else
        if caption.present?
          print "[#{compile_inline(caption)}]"
        end
        puts
      end

      @doc_status[:caption] = nil
      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n\n")

      puts "\\end{review#{type}}"
    end

    def box(lines, caption = nil)
      blank
      puts macro('reviewboxcaption', compile_inline(caption)) if caption.present?
      puts '\begin{reviewbox}'
      lines.each do |line|
        puts detab(line)
      end
      puts '\end{reviewbox}'
      blank
    end

    def ul_begin
      blank
      puts '\begin{itemize}'
    end

    def ul_item(lines)
      str = join_lines_to_paragraph(lines)
      unless @book.config['join_lines_by_lang']
        str = lines.map(&:chomp).join("\n")
      end

      str.sub!(/\A(\[)/) { '\lbrack{}' }
      puts '\item ' + str
    end

    def ul_end
      puts '\end{itemize}'
      blank
    end

    def ol_begin
      blank
      puts '\begin{enumerate}'
      return true unless @ol_num
      puts "\\setcounter{enumi}{#{@ol_num - 1}}"
      @ol_num = nil
    end

    def ol_item(lines, _num)
      str = join_lines_to_paragraph(lines)
      unless @book.config['join_lines_by_lang']
        str = lines.map(&:chomp).join("\n")
      end

      str.sub!(/\A(\[)/) { '\lbrack{}' }
      puts '\item ' + str
    end

    def ol_end
      puts '\end{enumerate}'
      blank
    end

    def dl_begin
      blank
      puts '\begin{description}'
    end

    def dt(str)
      str = str.gsub('[', '\lbrack{}').gsub(']', '\rbrack{}')
      puts '\item[' + str + '] \mbox{} \\\\'
    end

    def dd(lines)
      if @book.config['join_lines_by_lang']
        puts join_lines_to_paragraph(lines)
      else
        puts lines.map(&:chomp).join("\n")
      end
    end

    def dl_end
      puts '\end{description}'
      blank
    end

    def paragraph(lines)
      blank
      if @book.config['join_lines_by_lang']
        puts join_lines_to_paragraph(lines)
      else
        lines.each { |line| puts line }
      end
      blank
    end

    def parasep
      puts '\\parasep'
    end

    def read(lines)
      latex_block('quotation', lines)
    end

    alias_method :lead, :read

    def highlight?
      @book.config['highlight'] &&
        @book.config['highlight']['latex']
    end

    def highlight_listings?
      @book.config['highlight'] && @book.config['highlight']['latex'] == 'listings'
    end
    private :highlight_listings?

    def code_line(_type, line, _idx, _id, _caption, _lang)
      detab(line) + "\n"
    end

    def code_line_num(_type, line, first_line_num, idx, _id, _caption, _lang)
      detab((idx + first_line_num).to_s.rjust(2) + ': ' + line) + "\n"
    end

    def emlist(lines, caption = nil, lang = nil)
      blank
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewemlistlst', 'title', caption, lang)
      else
        common_code_block(nil, lines, 'reviewemlist', caption, lang) { |line, idx| code_line('emlist', line, idx, nil, caption, lang) }
      end
    end

    def emlistnum(lines, caption = nil, lang = nil)
      blank
      first_line_num = line_num
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewemlistnumlst', 'title', caption, lang, first_line_num: first_line_num)
      else
        common_code_block(nil, lines, 'reviewemlist', caption, lang) { |line, idx| code_line_num('emlistnum', line, first_line_num, idx, nil, caption, lang) }
      end
    end

    ## override Builder#list
    def list(lines, id, caption, lang = nil)
      if highlight_listings?
        common_code_block_lst(id, lines, 'reviewlistlst', 'caption', caption, lang)
      else
        common_code_block(id, lines, 'reviewlist', caption, lang) { |line, idx| code_line('list', line, idx, id, caption, lang) }
      end
    end

    ## override Builder#listnum
    def listnum(lines, id, caption, lang = nil)
      first_line_num = line_num
      if highlight_listings?
        common_code_block_lst(id, lines, 'reviewlistnumlst', 'caption', caption, lang, first_line_num: first_line_num)
      else
        common_code_block(id, lines, 'reviewlist', caption, lang) { |line, idx| code_line_num('listnum', line, first_line_num, idx, id, caption, lang) }
      end
    end

    def cmd(lines, caption = nil, lang = nil)
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewcmdlst', 'title', caption, lang)
      else
        blank
        common_code_block(nil, lines, 'reviewcmd', caption, lang) { |line, idx| code_line('cmd', line, idx, nil, caption, lang) }
      end
    end

    def common_code_block(id, lines, command, caption, _lang)
      @doc_status[:caption] = true
      captionstr = nil
      unless @book.config.check_version('2', exception: false)
        puts '\\begin{reviewlistblock}'
      end
      if caption.present?
        if command =~ /emlist/ || command =~ /cmd/ || command =~ /source/
          captionstr = macro(command + 'caption', compile_inline(caption))
        else
          begin
            if get_chap.nil?
              captionstr = macro('reviewlistcaption', "#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}")
            else
              captionstr = macro('reviewlistcaption', "#{I18n.t('list')}#{I18n.t('format_number_header', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}")
            end
          rescue KeyError
            error "no such list: #{id}"
          end
        end
      end
      @doc_status[:caption] = nil

      if caption_top?('list') && captionstr
        puts captionstr
      end

      body = ''
      lines.each_with_index do |line, idx|
        body.concat(yield(line, idx))
      end
      puts macro('begin', command)
      print body
      puts macro('end', command)

      if !caption_top?('list') && captionstr
        puts captionstr
      end

      unless @book.config.check_version('2', exception: false)
        puts '\\end{reviewlistblock}'
      end
      blank
    end

    def common_code_block_lst(_id, lines, command, title, caption, lang, first_line_num: 1)
      if title == 'title' && caption.blank? && @book.config.check_version('2', exception: false)
        print '\vspace{-1.5em}'
      end
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      args = make_code_block_args(title, caption, lang, first_line_num: first_line_num)
      puts %Q(\\begin{#{command}}[#{args}])
      print body
      puts %Q(\\end{#{command}})
      blank
    end

    def make_code_block_args(title, caption, lang, first_line_num: 1)
      caption_str = compile_inline((caption || ''))
      if title == 'title' && caption_str == '' && @book.config.check_version('2', exception: false)
        caption_str = '\relax' ## dummy charactor to remove lstname
      end
      lexer = if @book.config['highlight'] && @book.config['highlight']['lang']
                @book.config['highlight']['lang'] # default setting
              else
                ''
              end
      lexer = lang if lang.present?
      args = "language={#{lexer}}"
      if title == 'title' && caption_str == ''
        # ignore
      else
        args = "#{title}={#{caption_str}}," + args
      end
      if first_line_num != 1
        args << ",firstnumber=#{first_line_num}"
      end
      args
    end

    def source(lines, caption = nil, lang = nil)
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewsourcelst', 'title', caption, lang)
      else
        common_code_block(nil, lines, 'reviewsource', caption, lang) { |line, idx| code_line('source', line, idx, nil, caption, lang) }
      end
    end

    def image_header(id, caption)
    end

    def parse_metric(type, metric)
      s = super(type, metric)
      if @book.config['pdfmaker']['use_original_image_size'] && s.empty? && !metric.present?
        return ' ' # pass empty to \reviewincludegraphics
      end
      s
    end

    def handle_metric(str)
      if @book.config['pdfmaker']['image_scale2width'] && str =~ /\Ascale=([\d.]+)\Z/
        return "width=#{$1}\\maxwidth"
      end
      str
    end

    def result_metric(array)
      array.join(',')
    end

    def image_image(id, caption, metric)
      captionstr = nil
      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        captionstr = macro('caption', compile_inline(caption)) + "\n" if caption.present?
      else
        captionstr = macro('reviewimagecaption', compile_inline(caption)) + "\n" if caption.present?
      end
      captionstr << macro('label', image_label(id))
      @doc_status[:caption] = nil

      metrics = parse_metric('latex', metric)
      # image is always bound here
      puts "\\begin{reviewimage}%%#{id}"

      if caption_top?('image') && captionstr
        puts captionstr
      end

      command = 'reviewincludegraphics'
      if @book.config.check_version('2', exception: false)
        command = 'includegraphics'
      end

      if metrics.present?
        puts "\\#{command}[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\#{command}[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end

      if !caption_top?('image') && captionstr
        puts captionstr
      end

      puts '\end{reviewimage}'
    end

    def image_dummy(id, caption, lines)
      warn "image not bound: #{id}"
      puts '\begin{reviewdummyimage}'
      # path = @chapter.image(id).path
      puts "--[[path = #{id} (#{existence(id)})]]--"
      lines.each do |line|
        puts detab(line.rstrip)
      end
      puts macro('label', image_label(id))
      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        puts macro('caption', compile_inline(caption)) if caption.present?
      else
        puts macro('reviewimagecaption', compile_inline(caption)) if caption.present?
      end
      @doc_status[:caption] = nil
      puts '\end{reviewdummyimage}'
    end

    def existence(id)
      @chapter.image_bound?(id) ? 'exist' : 'not exist'
    end
    private :existence

    def image_label(id, chapter = nil)
      chapter ||= @chapter
      "image:#{chapter.id}:#{id}"
    end
    private :image_label

    def chapter_label
      "chap:#{@chapter.id}"
    end
    private :chapter_label

    def sec_label(sec_anchor)
      "sec:#{sec_anchor}"
    end
    private :sec_label

    def table_label(id, chapter = nil)
      chapter ||= @chapter
      "table:#{chapter.id}:#{id}"
    end
    private :table_label

    def bib_label(id)
      "bib:#{id}"
    end
    private :bib_label

    def column_label(id, chapter = nil)
      chapter ||= @chapter
      filename = chapter.id
      num = chapter.column(id).number
      "column:#{filename}:#{num}"
    end
    private :column_label

    def indepimage(lines, id, caption = nil, metric = nil)
      metrics = parse_metric('latex', metric)

      captionstr = nil
      if caption.present?
        @doc_status[:caption] = true
        captionstr = macro('reviewindepimagecaption',
                           %Q(#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{compile_inline(caption)}))
        @doc_status[:caption] = nil
      end

      if @chapter.image(id).path
        puts "\\begin{reviewimage}%%#{id}"

        if caption_top?('image') && captionstr
          puts captionstr
        end

        command = 'reviewincludegraphics'
        if @book.config.check_version('2', exception: false)
          command = 'includegraphics'
        end

        if metrics.present?
          puts "\\#{command}[#{metrics}]{#{@chapter.image(id).path}}"
        else
          puts "\\#{command}[width=\\maxwidth]{#{@chapter.image(id).path}}"
        end
      else
        warn "image not bound: #{id}"
        puts '\begin{reviewdummyimage}'
        puts "--[[path = #{escape(id)} (#{existence(id)})]]--"
        lines.each do |line|
          puts detab(line.rstrip)
        end
      end

      if !caption_top?('image') && captionstr
        puts captionstr
      end

      if @chapter.image(id).path
        puts '\end{reviewimage}'
      else
        puts '\end{reviewdummyimage}'
      end
    end

    alias_method :numberlessimage, :indepimage

    def table(lines, id = nil, caption = nil)
      if caption.present?
        if @book.config.check_version('2', exception: false)
          puts "\\begin{table}[h]%%#{id}"
        else
          puts "\\begin{table}%%#{id}"
        end
      end

      sepidx, rows = parse_table_rows(lines)
      begin
        if caption_top?('table') && caption.present?
          table_header(id, caption)
        end
      rescue KeyError
        error "no such table: #{id}"
      end
      table_begin(rows.first.size)
      table_rows(sepidx, rows)
      table_end
      if caption.present?
        unless caption_top?('table')
          table_header(id, caption)
        end
        puts '\end{table}'
      end
      blank
    end

    def table_rows(sepidx, rows)
      if sepidx
        sepidx.times do
          cno = -1
          tr(rows.shift.map do |s|
               cno += 1
               th(s, @cellwidth[cno])
             end)
        end
        rows.each do |cols|
          cno = -1
          tr(cols.map do |s|
               cno += 1
               td(s, @cellwidth[cno])
             end)
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          cno = 0
          tr([th(h, @cellwidth[0])] +
             cs.map do |s|
               cno += 1
               td(s, @cellwidth[cno])
             end)
        end
      end
    end

    def table_header(id, caption)
      if id.nil?
        if caption.present?
          @doc_status[:caption] = true
          puts macro('reviewtablecaption*', compile_inline(caption))
          @doc_status[:caption] = nil
        end
      else
        if caption.present?
          @doc_status[:caption] = true
          puts macro('reviewtablecaption', compile_inline(caption))
          @doc_status[:caption] = nil
        end
        puts macro('label', table_label(id))
      end
    end

    def table_begin(ncols)
      if @latex_tsize
        @tsize = @latex_tsize
      end

      if @tsize
        if @tsize =~ /\A[\d., ]+\Z/
          @cellwidth = @tsize.split(/\s*,\s*/)
          @cellwidth.collect! { |i| "p{#{i}mm}" }
          puts macro('begin', 'reviewtable', '|' + @cellwidth.join('|') + '|')
        else
          @cellwidth = separate_tsize(@tsize)
          puts macro('begin', 'reviewtable', @tsize)
        end
      else
        puts macro('begin', 'reviewtable', (['|'] * (ncols + 1)).join('l'))
        @cellwidth = ['l'] * ncols
      end
      puts '\\hline'
    end

    def separate_tsize(size)
      ret = []
      s = ''
      brace = nil
      size.split('').each do |ch|
        case ch
        when '|'
          next
        when '{'
          brace = true
          s << ch
        when '}'
          brace = nil
          s << ch
          ret << s
          s = ''
        else
          if brace
            s << ch
          else
            if s.empty?
              s << ch
            else
              ret << s
              s = ch
            end
          end
        end
      end

      unless s.empty?
        ret << s
      end

      ret
    end

    def table_separator
      # puts '\hline'
    end

    def th(s, cellwidth = 'l')
      if /\\\\/ =~ s
        if !@book.config.check_version('2', exception: false) && cellwidth =~ /\{/
          macro('reviewth', s.gsub("\\\\\n", '\\newline{}'))
        else
          ## use shortstack for @<br>
          macro('reviewth', macro('shortstack[l]', s))
        end
      else
        macro('reviewth', s)
      end
    end

    def td(s, cellwidth = 'l')
      if /\\\\/ =~ s
        if !@book.config.check_version('2', exception: false) && cellwidth =~ /\{/
          s.gsub("\\\\\n", '\\newline{}')
        else
          ## use shortstack for @<br>
          macro('shortstack[l]', s)
        end
      else
        s
      end
    end

    def tr(rows)
      print rows.join(' & ')
      puts ' \\\\  \hline'
    end

    def table_end
      puts macro('end', 'reviewtable')
      @tsize = nil
      @latex_tsize = nil
      @cellwidth = nil
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      unless @chapter.image_bound?(id)
        warn "image not bound: #{id}"
        image_dummy(id, caption, lines)
        return
      end

      captionstr = nil
      begin
        if caption.present?
          puts "\\begin{table}[h]%%#{id}"
          @doc_status[:caption] = true
          captionstr = macro('reviewimgtablecaption', compile_inline(caption))
          @doc_status[:caption] = nil
          if caption_top?('table')
            puts captionstr
          end
        end
        puts macro('label', table_label(id))
      rescue ReVIEW::KeyError
        error "no such table: #{id}"
      end
      imgtable_image(id, caption, metric)

      if caption.present?
        unless caption_top?('table')
          puts captionstr
        end
        puts '\end{table}'
      end
      blank
    end

    def imgtable_image(id, _caption, metric)
      metrics = parse_metric('latex', metric)
      # image is always bound here
      puts "\\begin{reviewimage}%%#{id}"

      command = 'reviewincludegraphics'
      if @book.config.check_version('2', exception: false)
        command = 'includegraphics'
      end

      if metrics.present?
        puts "\\#{command}[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\#{command}[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end
      puts '\end{reviewimage}'
    end

    def quote(lines)
      latex_block('quote', lines)
    end

    def center(lines)
      latex_block('center', lines)
    end

    alias_method :centering, :center

    def flushright(lines)
      latex_block('flushright', lines)
    end

    def texequation(lines, id = nil, caption = '')
      blank
      captionstr = nil

      if id
        puts macro('begin', 'reviewequationblock')
        if get_chap.nil?
          captionstr = macro('reviewequationcaption', "#{I18n.t('equation')}#{I18n.t('format_number_header_without_chapter', [@chapter.equation(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}")
        else
          captionstr = macro('reviewequationcaption', "#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}")
        end
      end

      if caption_top?('equation') && captionstr
        puts captionstr
      end

      puts macro('begin', 'equation*')
      lines.each do |line|
        puts line
      end
      puts macro('end', 'equation*')

      if !caption_top?('equation') && captionstr
        puts captionstr
      end

      if id
        puts macro('end', 'reviewequationblock')
      end

      blank
    end

    def latex_block(type, lines)
      blank
      puts macro('begin', type)
      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n\n")
      puts macro('end', type)
      blank
    end
    private :latex_block

    def direct(lines, fmt)
      return unless fmt == 'latex'
      lines.each do |line|
        puts line
      end
    end

    def comment(lines, comment = nil)
      return true unless @book.config['draft']
      lines ||= []
      unless comment.blank?
        lines.unshift(escape(comment))
      end
      str = lines.join('\par ')
      puts macro('pdfcomment', str)
    end

    def hr
      puts '\hrule'
    end

    def label(id)
      puts macro('label', id)
    end

    def pagebreak
      puts '\pagebreak'
    end

    def blankline
      puts '\vspace*{\baselineskip}'
    end

    def noindent
      print '\noindent'
    end

    def inline_chapref(id)
      title = super
      if @book.config['chapterlink']
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      if @book.config['chapterlink']
        "\\hyperref[chap:#{id}]{#{@book.chapter_index.number(id)}}"
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      title = super
      if @book.config['chapterlink']
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_pageref(id)
      "\\pageref{#{id}}"
    end

    # FIXME: use TeX native label/ref.
    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewlistref', I18n.t('format_number_without_chapter', [chapter.list(id).number]))
      else
        macro('reviewlistref', I18n.t('format_number', [get_chap(chapter), chapter.list(id).number]))
      end
    rescue KeyError
      error "unknown list: #{id}"
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewtableref', I18n.t('format_number_without_chapter', [chapter.table(id).number]), table_label(id, chapter))
      else
        macro('reviewtableref', I18n.t('format_number', [get_chap(chapter), chapter.table(id).number]), table_label(id, chapter))
      end
    rescue KeyError
      error "unknown table: #{id}"
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewimageref', I18n.t('format_number_without_chapter', [chapter.image(id).number]), image_label(id, chapter))
      else
        macro('reviewimageref', I18n.t('format_number', [get_chap(chapter), chapter.image(id).number]), image_label(id, chapter))
      end
    rescue KeyError
      error "unknown image: #{id}"
    end

    def inline_eq(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewequationref', I18n.t('format_number_without_chapter', [chapter.equation(id).number]))
      else
        macro('reviewequationref', I18n.t('format_number', [get_chap(chapter), chapter.equation(id).number]))
      end
    rescue KeyError
      error "unknown equation: #{id}"
    end

    def footnote(id, content)
      if @book.config['footnotetext'] || @foottext[id]
        if @doc_status[:column]
          warn "//footnote[#{id}] is in the column block. It is recommended to move out of the column block."
        end
        puts macro("footnotetext[#{@chapter.footnote(id).number}]", compile_inline(content.strip))
      end
    end

    def inline_fn(id)
      if @book.config['footnotetext']
        macro("footnotemark[#{@chapter.footnote(id).number}]", '')
      elsif @doc_status[:caption] || @doc_status[:table] || @doc_status[:column] || @doc_status[:dt]
        @foottext[id] = @chapter.footnote(id).number
        macro('protect\\footnotemark', '')
      else
        macro('footnote', compile_inline(@chapter.footnote(id).content.strip))
      end
    rescue KeyError
      error "unknown footnote: #{id}"
    end

    BOUTEN = '・'.freeze

    def inline_bou(str)
      macro('reviewbou', escape(str))
    end

    def compile_ruby(base, ruby)
      macro('ruby', escape(base), escape(ruby).gsub('\\textbar{}', '|'))
    end

    # math
    def inline_m(str)
      if @book.config.check_version('2', exception: false)
        " $#{str}$ "
      else
        "$#{str}$"
      end
    end

    # hidden index
    def inline_hi(str)
      index(str)
    end

    # index -> italic
    def inline_i(str)
      if @book.config.check_version('2', exception: false)
        macro('textit', escape(str))
      else
        macro('reviewit', escape(str))
      end
    end

    # index
    def inline_idx(str)
      escape(str) + index(str)
    end

    # hidden index
    def inline_hidx(str)
      index(str)
    end

    # bold
    def inline_b(str)
      if @book.config.check_version('2', exception: false)
        macro('textbf', escape(str))
      else
        macro('reviewbold', escape(str))
      end
    end

    # line break
    def inline_br(_str)
      "\\\\\n"
    end

    def inline_dtp(_str)
      # ignore
      ''
    end

    ## @<code> is same as @<tt>
    def inline_code(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', escape(str))
      else
        macro('reviewcode', escape(str))
      end
    end

    def nofunc_text(str)
      escape(str)
    end

    def inline_tt(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', escape(str))
      else
        macro('reviewtt', escape(str))
      end
    end

    def inline_del(str)
      macro('reviewstrike', escape(str))
    end

    def inline_tti(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', macro('textit', escape(str)))
      else
        macro('reviewtti', escape(str))
      end
    end

    def inline_ttb(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', macro('textbf', escape(str)))
      else
        macro('reviewttb', escape(str))
      end
    end

    def inline_bib(id)
      macro('reviewbibref', "[#{@chapter.bibpaper(id).number}]", bib_label(id))
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if n.present? && chap.number && over_secnolevel?(n)
        str = I18n.t('hd_quote', [chap.headline_index.number(id), compile_inline(chap.headline(id).caption)])
      else
        str = I18n.t('hd_quote_without_number', compile_inline(chap.headline(id).caption))
      end
      if @book.config['chapterlink']
        anchor = n.gsub(/\./, '-')
        macro('reviewsecref', str, sec_label(anchor))
      else
        str
      end
    end

    def inline_column_chap(chapter, id)
      macro('reviewcolumnref',
            I18n.t('column', compile_inline(chapter.column(id).caption)),
            column_label(id, chapter))
    rescue KeyError
      error "unknown column: #{id}"
    end

    def inline_raw(str) # rubocop:disable Lint/UselessMethodDefinition
      super(str)
    end

    def inline_sub(str)
      macro('textsubscript', escape(str))
    end

    def inline_sup(str)
      macro('textsuperscript', escape(str))
    end

    def inline_em(str)
      macro('reviewem', escape(str))
    end

    def inline_strong(str)
      macro('reviewstrong', escape(str))
    end

    def inline_u(str)
      macro('reviewunderline', escape(str))
    end

    def inline_ami(str)
      macro('reviewami', escape(str))
    end

    def inline_icon(id)
      if @chapter.image(id).path
        command = 'reviewincludegraphics'
        if @book.config.check_version('2', exception: false)
          command = 'includegraphics'
        end
        macro(command, @chapter.image(id).path)
      else
        warn "image not bound: #{id}"
        "\\verb|--[[path = #{id} (#{existence(id)})]]--|"
      end
    end

    def inline_uchar(str)
      if @texcompiler && @texcompiler.start_with?('platex')
        # with otf package
        macro('UTF', escape(str))
      else
        # passthrough
        [str.to_i(16)].pack('U')
      end
    end

    def inline_comment(str)
      if @book.config['draft']
        macro('pdfcomment', escape(str))
      else
        ''
      end
    end

    def inline_tcy(str)
      macro('rensuji', escape(str))
    end

    def inline_balloon(str)
      macro('reviewballoon', escape(str))
    end

    def bibpaper_header(id, caption)
      puts "[#{@chapter.bibpaper(id).number}] #{compile_inline(caption)}"
      puts macro('label', bib_label(id))
    end

    def bibpaper_bibpaper(_id, _caption, lines)
      if @book.config['join_lines_by_lang']
        print split_paragraph(lines).join("\n\n")
      else
        print split_paragraph(lines).map(&:chomp).join("\n")
      end

      puts ''
    end

    def index(str)
      sa = str.split('<<>>')

      sa.map! do |item|
        if @index_db[item]
          escape_index(escape(@index_db[item])) + '@' + escape_index(escape(item))
        else
          if item =~ /\A[[:ascii:]]+\Z/ || @index_mecab.nil?
            esc_item = escape_index(escape(item))
            if esc_item == item
              esc_item
            else
              "#{escape_index(item)}@#{esc_item}"
            end
          else
            yomi = NKF.nkf('-w --hiragana', @index_mecab.parse(item).force_encoding('UTF-8').chomp)
            escape_index(escape(yomi)) + '@' + escape_index(escape(item))
          end
        end
      end

      "\\index{#{sa.join('!')}}"
    end

    def compile_kw(word, alt)
      if alt
        macro('reviewkw', escape(word)) + "（#{escape(alt.strip)}）"
      else
        macro('reviewkw', escape(word))
      end
    end

    def compile_href(url, label)
      if /\A[a-z]+:/ =~ url
        if label
          macro('href', escape_url(url), escape(label))
        else
          macro('url', escape_url(url))
        end
      else
        macro('ref', url)
      end
    end

    def latextsize(str)
      @latex_tsize = str
    end

    def image_ext
      'pdf'
    end

    def olnum(num)
      @ol_num = num.to_i
    end
  end
end
