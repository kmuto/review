# Copyright (c) 2008-2017 Minero Aoki, Kenshi Muto
#               2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/textutils'

module ReVIEW
  #
  # RSTBuilder is a builder for reStructuredText (http://docutils.sourceforge.net/rst.html).
  # reStructuredText is used in Sphinx (http://www.sphinx-doc.org/).
  #
  # If you want to use `ruby`, `del` and `column`, you sould use sphinxcontrib-textstyle
  # package (https://pypi.python.org/pypi/sphinxcontrib-textstyle).
  #
  class RSTBuilder < Builder
    include TextUtils

    %i[ttbold hint maru keytop labelref ref balloon strong].each { |e| Compiler.definline(e) }
    Compiler.defsingle(:dtp, 1)

    Compiler.defblock(:insn, 1)
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:securty, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:reference, 0)
    Compiler.defblock(:term, 0)
    Compiler.defblock(:practice, 0)
    Compiler.defblock(:expert, 0)
    Compiler.defblock(:link, 0..1)
    Compiler.defblock(:shoot, 0..1)

    def pre_paragraph
      ''
    end

    def post_paragraph
      ''
    end

    def image_ext
      'png'
    end

    def extname
      '.rst'
    end

    def builder_init_file
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
      @blank_seen = true
      @sec_counter = SecCounter.new(5, @chapter)
      @ul_indent = 0
      @ol_indent = 0
      @in_role = false
      @in_table = false
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

    def headline(level, label, caption)
      blank
      if label
        puts ".. _#{label}:"
        blank
      end
      p = '='
      case level
      when 1 then
        unless label
          puts ".. _#{@chapter.name}:"
          blank
        end
        puts '=' * caption.size * 2
      when 2 then
        p = '='
      when 3 then
        p = '-'
      when 4 then
        p = '`'
      when 5 then
        p = '~'
      end

      puts caption
      puts p * caption.size * 2
      blank
    end

    def ul_begin
      blank
      @ul_indent += 1
    end

    def ul_item(lines)
      puts '  ' * (@ul_indent - 1) + "* #{lines.join}"
    end

    def ul_end
      @ul_indent -= 1
      blank
    end

    def ol_begin
      blank
      @ol_indent += 1
    end

    def ol_item(lines, _num)
      puts '  ' * (@ol_indent - 1) + "#. #{lines.join}"
    end

    def ol_end
      @ol_indent -= 1
      blank
    end

    def dl_begin
    end

    def dt(line)
      puts line
    end

    def dd(lines)
      split_paragraph(lines).each { |paragraph| puts "  #{paragraph.gsub(/\n/, '')}" }
    end

    def dl_end
    end

    def paragraph(lines)
      pre = ''
      pre = '   ' if @in_role == true
      puts pre + lines.join
      puts "\n"
    end

    def read(lines)
      puts split_paragraph(lines).map { |line| "  #{line}" }.join
      blank
    end

    alias_method :lead, :read

    def hr
      puts '----'
    end

    def inline_list(id)
      " :numref:`#{id}` "
    end

    def list_header(id, _caption, _lang)
      puts ".. _#{id}:"
      blank
    end

    def list_body(_id, lines, _lang)
      lines.each { |line| puts '-' + detab(line) }
    end

    def base_block(_type, lines, caption = nil)
      blank
      puts compile_inline(caption) unless caption.nil?
      puts lines.join("\n")
      blank
    end

    def base_parablock(type, lines, caption = nil)
      puts ".. #{type}::"
      blank
      puts "   #{compile_inline(caption)}" unless caption.nil?
      puts '   ' + split_paragraph(lines).join("\n")
      blank
    end

    def emlist(lines, caption = nil, lang = nil)
      blank
      if caption
        puts caption
        print "\n"
      end
      lang ||= 'none'
      puts ".. code-block:: #{lang}"
      blank
      lines.each { |line| puts '   ' + detab(line) }
      blank
    end

    def emlistnum(lines, caption = nil, lang = nil)
      blank
      if caption
        puts caption
        print "\n"
      end
      lang ||= 'none'
      puts ".. code-block:: #{lang}"
      puts '   :linenos:'
      blank
      lines.each { |line| puts '   ' + detab(line) }
      blank
    end

    def listnum_body(lines, _lang)
      lines.each_with_index { |line, i| puts(i + 1).to_s.rjust(2) + ": #{line}" }
      blank
    end

    def cmd(lines, _caption = nil)
      puts '.. code-block:: bash'
      lines.each { |line| puts '   ' + detab(line) }
    end

    def quote(lines)
      blank
      puts lines.map { |line| "  #{line}" }.join
      blank
    end

    def inline_table(id)
      "表 :numref:`#{id}` "
    end

    def inline_img(id)
      " :numref:`#{id}` "
    end

    def image_image(id, caption, metric)
      chapter, id = extract_chapter_id(id)
      scale = metric.split('=')[1].to_f * 100 if metric

      puts ".. _#{id}:"
      blank
      puts ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}"
      puts "   :scale:#{scale}%" if scale
      blank
      puts "   #{caption}"
      blank
    end

    def image_dummy(id, caption, lines)
      chapter, id = extract_chapter_id(id)
      puts ".. _#{id}:"
      blank
      puts ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}"
      blank
      puts "   #{caption}"
      puts "   #{lines.join}"
      blank
    end

    def texequation(lines)
      puts '.. math::'
      blank
      puts lines.map { |line| "   #{line}" }.join
      blank
    end

    def table_header(id, caption)
      unless id.nil?
        blank
        puts ".. _#{id}:"
      end
      blank
      puts ".. list-table:: #{compile_inline(caption)}"
      puts '   :header-rows: 1'
      blank
    end

    def table_begin(ncols)
    end

    def tr(rows)
      first = true
      rows.each do |row|
        if first
          puts "   * - #{row}"
          first = false
        else
          puts "     - #{row}"
        end
      end
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

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def comment(lines, _comment = nil)
      puts lines.map { |line| "  .. #{line}" }.join
    end

    def footnote(id, str)
      puts ".. [##{id.sub(' ', '_')}] #{compile_inline(str)}"
      blank
    end

    def inline_fn(id)
      " [##{id.sub(' ', '_')}]_ "
    end

    def compile_ruby(base, ruby)
      " :ruby:`#{base}`<#{ruby}>`_ "
    end

    def compile_kw(word, alt)
      if alt
        then " **#{word}（#{alt.strip}）** "
      else " **#{word}** "
      end
    end

    def compile_href(url, label)
      label = url if label.blank?
      " `#{label} <#{url}>`_ "
    end

    def inline_sup(str)
      " :superscript:`#{str}` "
    end

    def inline_sub(str)
      " :subscript:`#{str}` "
    end

    def inline_raw(str)
      matched = str.match(/\|(.*?)\|(.*)/)
      if matched
        matched[2].gsub('\\n', "\n")
      else
        str.gsub('\\n', "\n")
      end
    end

    def inline_hint(str)
      # TODO: hint is not default role
      " :hint:`#{str}` "
    end

    def inline_maru(str)
      # TODO: maru is not default role
      " :maru:`#{str}` "
    end

    def inline_idx(str)
      " :index:`#{str}` "
    end

    def inline_hidx(str)
      " :index:`#{str}` "
    end

    def inline_ami(str)
      # TODO: ami is not default role
      " :ami:`#{str}` "
    end

    def inline_i(str)
      " *#{str.gsub('*', '\*')}* "
    end

    def inline_b(str)
      " **#{str.gsub('*', '\*')}** "
    end

    alias_method :inline_strong, :inline_b

    def inline_tt(str)
      " ``#{str}`` "
    end

    alias_method :inline_ttb, :inline_tt  # TODO
    alias_method :inline_tti, :inline_tt  # TODO

    alias_method :inline_ttbold, :inline_ttb

    def inline_u(str)
      " :subscript:`#{str}` "
    end

    def inline_icon(id)
      " :ref:`#{id}` "
    end

    def inline_bou(str)
      # TODO: bou is not default role
      " :bou:`#{str}` "
    end

    def inline_keytop(str)
      # TODO: keytop is not default role
      " :keytop:`#{str}` "
    end

    def inline_balloon(str)
      %Q(\t←#{str.gsub(/@maru\[(\d+)\]/, inline_maru('\1'))})
    end

    def inline_uchar(str)
      [str.to_i(16)].pack('U')
    end

    def inline_comment(str)
      if @book.config['draft']
        str
      else
        ''
      end
    end

    def inline_m(str)
      " :math:`#{str}` "
    end

    def inline_hd_chap(_chap, id)
      " :ref:`#{id}` "
    end

    def noindent
      # TODO
    end

    def nonum_begin(_level, _label, caption)
      puts ".. rubric: #{compile_inline(caption)}"
      blank
    end

    def nonum_end(level)
    end

    def common_column_begin(_type, caption)
      blank
      puts ".. column:: #{compile_inline(caption)}"
      blank
      @in_role = true
    end

    def common_column_end(_type)
      @in_role = false
      blank
    end

    def column_begin(_level, _label, caption)
      common_column_begin('column', caption)
    end

    def column_end(_level)
      common_column_end('column')
    end

    def xcolumn_begin(_level, _label, caption)
      common_column_begin('xcolumn', caption)
    end

    def xcolumn_end(_level)
      common_column_end('xcolumn')
    end

    def world_begin(_level, _label, caption)
      common_column_begin('world', caption)
    end

    def world_end(_level)
      common_column_end('world')
    end

    def hood_begin(_level, _label, caption)
      common_column_begin('hood', caption)
    end

    def hood_end(_level)
      common_column_end('hood')
    end

    def edition_begin(_level, _label, caption)
      common_column_begin('edition', caption)
    end

    def edition_end(_level)
      common_column_end('edition')
    end

    def insideout_begin(_level, _label, caption)
      common_column_begin('insideout', caption)
    end

    def insideout_end(_level)
      common_column_end('insideout')
    end

    def ref_begin(_level, _label, caption)
      common_column_begin('ref', caption)
    end

    def ref_end(_level)
      common_column_end('ref')
    end

    def sup_begin(_level, _label, caption)
      common_column_begin('sup', caption)
    end

    def sup_end(_level)
      common_column_end('sup')
    end

    def flushright(lines)
      base_parablock 'flushright', lines, nil
    end

    def centering(lines)
      base_parablock 'centering', lines, nil
    end

    def note(lines, caption = nil)
      base_parablock 'note', lines, caption
    end

    def memo(lines, caption = nil)
      base_parablock 'memo', lines, caption
    end

    def tip(lines, caption = nil)
      base_parablock 'tip', lines, caption
    end

    def info(lines, caption = nil)
      base_parablock 'info', lines, caption
    end

    def planning(lines, caption = nil)
      base_parablock 'planning', lines, caption
    end

    def best(lines, caption = nil)
      base_parablock 'best', lines, caption
    end

    def important(lines, caption = nil)
      base_parablock 'important', lines, caption
    end

    def security(lines, caption = nil)
      base_parablock 'security', lines, caption
    end

    def caution(lines, caption = nil)
      base_parablock 'caution', lines, caption
    end

    def term(lines)
      base_parablock 'term', lines, nil
    end

    def link(lines, caption = nil)
      base_parablock 'link', lines, caption
    end

    def notice(lines, caption = nil)
      base_parablock 'notice', lines, caption
    end

    def point(lines, caption = nil)
      base_parablock 'point', lines, caption
    end

    def shoot(lines, caption = nil)
      base_parablock 'shoot', lines, caption
    end

    def reference(lines)
      base_parablock 'reference', lines, nil
    end

    def practice(lines)
      base_parablock 'practice', lines, nil
    end

    def expert(lines)
      base_parablock 'expert', lines, nil
    end

    def insn(lines, caption = nil)
      base_block 'insn', lines, caption
    end

    def warning(lines, caption = nil)
      base_parablock 'warning', lines, caption
    end

    alias_method :box, :insn

    def indepimage(_lines, id, caption = '', _metric = nil)
      chapter, id = extract_chapter_id(id)
      puts ".. _#{id}:"
      blank
      puts ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}"
      blank
      puts "   #{compile_inline(caption)}"
      blank
    end

    alias_method :numberlessimage, :indepimage

    def label(id)
      puts ".. _#{id}:"
      blank
    end

    def dtp(str)
      # FIXME
    end

    def bpo(lines)
      base_block 'bpo', lines, nil
    end

    def inline_dtp(_str)
      ''
    end

    def inline_del(str)
      " :del:`#{str}` "
    end

    def inline_code(str)
      " :code:`#{str}` "
    end

    def inline_br(_str)
      "\n"
    end

    def text(str)
      str
    end

    def inline_chap(id)
      super
    end

    def inline_chapref(id)
      " :numref:`#{id}` "
    end

    def source(lines, caption = nil, _lang = nil)
      base_block 'source', lines, caption
    end

    def inline_ttibold(str)
      # TODO
      " **#{str}** "
    end

    def inline_labelref(idref)
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      " :ref:`#{idref}` "
    end

    def circle_begin(_level, _label, caption)
      puts "・\t#{caption}"
    end

    def circle_end(level)
    end

    def nofunc_text(str)
      str
    end

    def bib_label(id)
      " [#{id}]_ "
    end
    private :bib_label

    def bibpaper_header(id, caption)
    end

    def bibpaper_bibpaper(id, caption, lines)
      puts ".. [#{id}] #{compile_inline(caption)} #{split_paragraph(lines).join}"
    end

    def inline_warn(str)
      " :warn:`#{str}` "
    end

    def inline_bib(id)
      " [#{id}]_ "
    end
  end
end # module ReVIEW
