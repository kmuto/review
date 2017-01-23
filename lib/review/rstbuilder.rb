# encoding: utf-8
#
# Copyright (c) 2002-2006 Minero Aoki
#               2008-2016 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/textutils'

module ReVIEW

  class RSTBuilder < Builder

    include TextUtils

    [:ttbold, :hint, :maru, :keytop, :labelref, :ref, :pageref, :balloon, :strong].each {|e|
      Compiler.definline(e)
    }
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
      "png"
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

    def warn(msg)
      $stderr.puts "#{@location.filename}:#{@location.lineno}: warning: #{msg}"
    end

    def error(msg)
      $stderr.puts "#{@location.filename}:#{@location.lineno}: error: #{msg}"
    end

    def headline(level, label, caption)
      blank
      if label
        puts '.. ' + label
        blank
      end
      p = "="
      case level
      when 1 then
        puts "=" * caption.size * 2
      when 2 then
        p = '='
      when 3 then
        p = '-'
      when 4 then
        p = '`'
      when 5 then
        p = '~'
      end

      puts "#{caption}"
      puts p * caption.size * 2
      blank    end

    def ul_begin
      blank
      @ul_indent += 1
    end

    def ul_item(lines)
      puts "  " * (@ul_indent - 1) + "* #{lines.join}"
    end

    def ul_end
      @ul_indent -= 1
      blank
    end

    def ol_begin
      blank
      @ol_indent += 1
    end

    def ol_item(lines, num)
      puts "  " * (@ol_indent - 1) + "#. #{lines.join}"
    end

    def ol_end
      @ol_indent -= 1
      blank
    end

    def dl_begin
    end

    def dt(line)
      puts "#{line}"
    end

    def dd(lines)
      split_paragraph(lines).each do |paragraph|
        puts "  #{paragraph.gsub(/\n/, '')}"
      end
    end

    def dl_end
    end

    def paragraph(lines)
      pre = ""
      if @in_role == true
        pre = "   "
      end
      puts pre + lines.join
      puts "\n"
    end

    def read(lines)
      puts split_paragraph(lines).map{|line| "  #{line}"}.join("")
      blank
    end

    alias_method :lead, :read

    def hr
      puts "----"
    end

    def inline_list(id)
      " :numref:`#{id}` "
    end

    def list_header(id, caption, lang)
      puts ".. _#{id}:"
      blank
    end

    def list_body(id, lines, lang)
      lines.each do |line|
        puts '-' + detab(line)
      end
    end

    def base_block(type, lines, caption = nil)
      blank
      puts "#{compile_inline(caption)}" unless caption.nil?
      puts lines.join("\n")
      blank
    end

    def base_parablock(type, lines, caption = nil)
      puts ".. #{type}::"
      blank
      puts "   #{compile_inline(caption)}" unless caption.nil?
      puts "   " + split_paragraph(lines).join("\n")
      blank
    end

    def emlist(lines, caption = nil, lang = nil)
      blank
      if caption
        puts caption
        print "\n"
      end
      lang ||= "none"
      puts ".. code-block:: #{lang}"
      blank
      lines.each do |line|
        puts "   " + detab(line)
      end
      blank
    end

    def emlistnum(lines, caption = nil, lang = nil)
      blank
      if caption
        puts caption
        print "\n"
      end
      lang ||= "none"
      puts ".. code-block:: #{lang}"
      puts "   :linenos:"
      blank
      lines.each do |line|
        puts "   " + detab(line)
      end
      blank
    end

    def listnum_body(lines, lang)
      lines.each_with_index do |line, i|
        puts (i + 1).to_s.rjust(2) + ": #{line}"
      end
      blank
    end

    def cmd(lines, caption = nil)
      puts ".. code-block:: bash"
      lines.each do |line|
        puts "   " + detab(line)
      end
    end

    def quote(lines)
      blank
      puts lines.map{|line| "  #{line}"}.join("")
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
      puts ".. _#{id}:"
      blank
      puts ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}"
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
      puts ".. math::"
      blank
      puts lines.map{|line| "   #{line}"}.join("")
      blank
    end

    def table_header(id, caption)
      blank
      puts ".. _#{id}:"
      blank
      puts ".. list-table:: #{compile_inline(caption)}"
      puts "   :header-rows: 1"
      blank
    end

    def table_begin(ncols)
    end

    def tr(rows)
      first = true
      rows.each{|row|
        if first
          puts "   * - #{row}"
          first = false
        else
          puts "     - #{row}"
        end
      }
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

    def comment(lines, comment = nil)
      puts lines.map{|line| "  .. #{line}"}.join("")
    end

    def footnote(id, str)
      puts ".. [##{id.sub(" ", "_")}] #{compile_inline(str)}"
      blank
    end

    def inline_fn(id)
      " [##{id.sub(" ", "_")}]_ "
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
      " :superscript:`str` "
    end

    def inline_sub(str)
      " :subscript:`str` "
    end

    def inline_raw(str)
      %Q[#{super(str).gsub("\\n", "\n")}]
    end

    def inline_hint(str)
      " :hint:`#{str}` "  # TODO: hint is not default directive
    end

    def inline_maru(str)
      " :maru:`#{str}` "  # TODO: maru is not default directive
    end

    def inline_idx(str)
      " :index:`#{str}` "
    end

    def inline_hidx(str)
      " :index:`#{str}` "
    end

    def inline_ami(str)
      " :ami:`#{str}` "  # TODO: ami is not default directive
    end

    def inline_i(str)
      " *#{str.gsub(/\*/, '\*')}* "
    end

    def inline_b(str)
      " **#{str.gsub(/\*/, '\*')}** "
    end

    alias_method :inline_strong, :inline_b

    def inline_tt(str)
      " ``#{str}`` "
    end

    alias_method :inline_ttb, :inline_tt  # TODO
    alias_method :inline_tti, :inline_tt  # TODO

    alias_method :inline_ttbold, :inline_ttb

    def inline_u(str)
      " :subscript:`str` "
    end

    def inline_icon(id)
      " :ref:`#{id}` "
    end

    def inline_bou(str)
      " :bou:`#{str}` "  # TODO: bou is not default directive
    end

    def inline_keytop(str)
      " :keytop:`#{str}` "  # TODO: keytop is not default directive
    end

    def inline_balloon(str)
      %Q(\t←#{str.gsub(/@maru\[(\d+)\]/, inline_maru('\1'))})
    end

    def inline_uchar(str)
      [str.to_i(16)].pack("U")
    end

    def inline_comment(str)
      if @book.config["draft"]
        "◆→#{str}←◆"
      else
        ""
      end
    end

    def inline_m(str)
      " :math:`#{str}` "
    end

    def inline_hd_chap(chap, id)
      " :ref:`#{id}<chap>` "
    end

    def noindent
      # TODO
    end

    def nonum_begin(level, label, caption)
      puts ".. rubric: #{compile_inline(caption)}"
    end

    def nonum_end(level)
    end

   def common_column_begin(type, caption)
      blank
      puts ".. column:: #{compile_inline(caption)}"
      blank
      @in_role = true
    end

    def common_column_end(type)
      @in_role = false
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

    def warning(lines, caption = nil)
      base_parablock "warning", lines, caption
    end

    alias_method :box, :insn

    def indepimage(id, caption="", metric=nil)
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
      base_block "bpo", lines, nil
    end

    def inline_dtp(str)
      ""
    end

    def inline_del(str)
      " :del:`str` "
    end

    def inline_code(str)
      " :code:`#{str}` "
    end

    def inline_br(str)
      %Q(\n)
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

    def source(lines, caption = nil, lang = nil)
      base_block "source", lines, caption
    end

    def inline_ttibold(str)
      " **#{str}** "  # TODO
    end

    def inline_labelref(idref)
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      " :ref:`#{idref}` "
    end

    def circle_begin(level, label, caption)
      puts "・\t#{caption}"
    end

    def circle_end(level)
    end

    def nofunc_text(str)
      str
    end

    def bib_label(id)
      " :cite:`#{id}` "  # using sphinxcontrib-bibtex
    end
    private :bib_label

    def bibpaper_header(id, caption)
      puts ".. [##{id}] #{compile_inline(caption)}"
    end

    def bibpaper_bibpaper(id, caption, lines)
      print split_paragraph(lines).join("")
      puts ""
    end

    def inline_warn(str)
      " :warn:`#{str}` "
    end

    def inline_bib(id)
      " [#{id}]_ "
    end

  end

end # module ReVIEW
