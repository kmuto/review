require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'

class LATEXBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = LATEXBuilder.new()
    @param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, EPUBBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
      "stylesheet" => nil,  # for EPUBBuilder
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Chapter.new(nil, 1, 'chap1', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|\\chapter{this is test.}\n|, @builder.result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|\\chapter*{this is test.}\n|, @builder.result
  end

  def test_headline_level1_with_inlinetag
    @builder.headline(1,"test","this @<b>{is} test.<&\"_>")
    assert_equal %Q|\\chapter{this \\textbf{is} test.\\textless{}\\&"\\textunderscore{}\\textgreater{}}\n|, @builder.result
  end

  def test_headline_level2
    @builder.headline(2,"test","this is test.")
    assert_equal %Q|\\section{this is test.}\n|, @builder.result
  end

  def test_headline_level3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\\subsection*{this is test.}\n|, @builder.result
  end


  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\\subsection{this is test.}\n|, @builder.result
  end

  def test_label
    @builder.label("label_test")
    assert_equal %Q|\\label{label_test}\n|, @builder.result
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|\\href{http://github.com}{GitHub}|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|\\href{http://github.com}{http://github.com}|, ret
  end

  def test_href_with_underscore
    ret = @builder.compile_href("http://example.com/aaa/bbb", "AAA_BBB")
    assert_equal %Q|\\href{http://example.com/aaa/bbb}{AAA\\textunderscore{}BBB}|, ret
  end

  def test_inline_br
    ret = @builder.inline_br("")
    assert_equal %Q|\\\\\n|, ret
  end

  def test_inline_br_with_other_strings
    ret = @builder.compile_inline("abc@<br>{}def")
    assert_equal %Q|abc\\\\\ndef|, ret
  end

  def test_inline_u
    ret = @builder.compile_inline("abc@<u>{def}ghi")
    assert_equal %Q|abc\\Underline{def}ghi|, ret
  end

  def test_inline_i
    ret = @builder.compile_inline("abc@<i>{def}ghi")
    assert_equal %Q|abc\\textit{def}ghi|, ret
  end

  def test_inline_i_and_escape
    ret = @builder.compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test \\textit{inline\\textless{}\\&;\\reviewbackslash{} test} test2|, ret
  end

  def test_inline_dtp
    ret = @builder.compile_inline("abc@<dtp>{def}ghi")
    assert_equal %Q|abcghi|, ret
  end

  def test_inline_code
    ret = @builder.compile_inline("abc@<code>{def}ghi")
    assert_equal %Q|abc\\texttt{def}ghi|, ret
  end

  def test_inline_raw
    ret = @builder.compile_inline("@<raw>{@<tt>{inline!$%\\}}")
    assert_equal %Q|@\\textless{}tt\\textgreater{}\\{inline!\\textdollar{}\\%\\}|, ret
  end

  def test_inline_sup
    ret = @builder.compile_inline("abc@<sup>{def}")
    assert_equal %Q|abc\\textsuperscript{def}|, ret
  end

  def test_inline_sub
    ret = @builder.compile_inline("abc@<sub>{def}")
    assert_equal %Q|abc\\textsubscript{def}|, ret
  end

  def test_inline_b
    ret = @builder.compile_inline("abc@<b>{def}")
    assert_equal %Q|abc\\textbf{def}|, ret
  end

  def test_inline_b_and_escape
    ret = @builder.compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test \\textbf{inline\\textless{}\\&;\\reviewbackslash{} test} test2|, ret
  end
  def test_inline_em
    ret = @builder.compile_inline("abc@<em>{def}")
    assert_equal %Q|abc\\textbf{def}|, ret
  end

  def test_inline_strong
    ret = @builder.compile_inline("abc@<strong>{def}")
    assert_equal %Q|abc\\textbf{def}|, ret
  end

  def test_inline_u
    ret = @builder.compile_inline("abc@<u>{def}ghi")
    assert_equal %Q|abc\\Underline{def}ghi|, ret
  end

  def test_inline_m
    ret = @builder.compile_inline("abc@<m>{\\alpha^n = \inf < 2}ghi")
    assert_equal "abc $\\alpha^n = inf < 2$ ghi", ret
  end

  def test_inline_tt
    ret = @builder.compile_inline("test @<tt>{inline test} test2")
    assert_equal %Q|test \\texttt{inline test} test2|, ret
  end

  def test_inline_tt_endash
    ret = @builder.compile_inline("test @<tt>{in-line --test ---foo ----bar -----buz} --test2")
    assert_equal %Q|test \\texttt{in-line {-}{-}test {-}{-}-foo {-}{-}{-}{-}bar {-}{-}{-}{-}-buz} --test2|, ret
  end

  def test_inline_tti
    ret = @builder.compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test \\texttt{\\textit{inline test}} test2|, ret
  end

  def test_inline_ttb
    ret = @builder.compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test \\texttt{\\textbf{inline test}} test2|, ret
  end

  def test_inline_uchar
    ret = @builder.compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test \\UTF{2460} test2|, ret
  end

  def test_headline_level1
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|\\chapter{this is test.}\n|, @builder.result
  end

  def test_cmd
    lines = ["foo", "bar", "","buz"]
    @builder.cmd(lines)
    assert_equal %Q|\n\\begin{reviewcmd}\n\\begin{alltt}\nfoo\nbar\n\nbuz\n\\end{alltt}\n\\end{reviewcmd}\n|, @builder.result
  end

  def test_cmd_caption
    lines = ["foo", "bar", "","buz"]
    @builder.cmd(lines, "cap1")
    assert_equal %Q|\n\\reviewcmdcaption{cap1}\n\\begin{reviewcmd}\n\\begin{alltt}\nfoo\nbar\n\nbuz\n\\end{alltt}\n\\end{reviewcmd}\n|, @builder.result
  end

  def test_emlist
    lines = ["foo", "bar", "","buz"]
    @builder.emlist(lines)
    assert_equal %Q|\n\\begin{reviewemlist}\n\\begin{alltt}\nfoo\nbar\n\nbuz\n\\end{alltt}\n\\end{reviewemlist}\n|, @builder.result
  end

  def test_emlist_caption
    lines = ["foo", "bar", "","buz"]
    @builder.emlist(lines, "cap1")
    assert_equal %Q|\n\\reviewemlistcaption{cap1}\n\\begin{reviewemlist}\n\\begin{alltt}\nfoo\nbar\n\nbuz\n\\end{alltt}\n\\end{reviewemlist}\n|, @builder.result
  end

  def test_quote
    lines = ["foo", "bar", "","buz"]
    @builder.quote(lines)
    assert_equal %Q|\n\\begin{quote}\nfoobar\n\nbuz\n\\end{quote}\n|, @builder.result
  end

  def test_memo
    @builder.memo(["test1", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|\\begin{reviewminicolumn}\n\\reviewminicolumntitle{this is \\textbf{test}\\textless{}\\&\\textgreater{}\\textunderscore{}}\ntest1\n\ntest<i>2</i>\n\\end{reviewminicolumn}\n|, @builder.result
  end

  def test_flushright
    @builder.flushright(["foo", "bar", "","buz"])
    assert_equal %Q|\n\\begin{flushright}\nfoobar\n\nbuz\n\\end{flushright}\n|, @builder.raw_result
  end

  def test_noindent
    @builder.noindent
    @builder.paragraph(["foo", "bar"])
    @builder.paragraph(["foo2", "bar2"])
    assert_equal %Q|\\noindent\nfoo\nbar\n\nfoo2\nbar2\n|, @builder.raw_result
  end

  def test_raw
    @builder.raw("<&>\\n")
    assert_equal %Q|<&>\n|, @builder.result
  end

  def test_image
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo",nil)
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\label{image:chap1:sampleimg}\n\\caption{sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\label{image:chap1:sampleimg}\n\\caption{sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    @builder.indepimage("sampleimg","sample photo",nil)
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    @builder.indepimage("sampleimg",nil,nil)
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    @builder.indepimage("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    @builder.indepimage("sampleimg",nil,"scale=1.2")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_bib
    def @chapter.bibpaper(id)
      BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    assert_equal "[1]", @builder.inline_bib("samplebib")
  end

  def test_bibpaper
    def @chapter.bibpaper(id)
      BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    @builder.bibpaper(["a", "b"], "samplebib", "sample bib @<b>{bold}")
    assert_equal %Q|[1] sample bib \\textbf{bold}\n\na\nb\n\n|, @builder.raw_result
  end

  def test_bibpaper_without_body
    def @chapter.bibpaper(id)
      BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    @builder.bibpaper([], "samplebib", "sample bib")
    assert_equal %Q|[1] sample bib\n\n|, @builder.raw_result
  end

  def column_helper(review)
    chap_singleton = class << @chapter; self; end
    chap_singleton.send(:define_method, :content) { review }
    @compiler.compile(@chapter)
  end

  def test_column_1
    review =<<-EOS
===[column] prev column

inside prev column

===[column] test

inside column

===[/column]
EOS
    expect =<<-EOS

\\begin{reviewcolumn}
\\reviewcolumnhead{}{prev column}

inside prev column

\\end{reviewcolumn}

\\begin{reviewcolumn}
\\reviewcolumnhead{}{test}

inside column

\\end{reviewcolumn}
EOS
    assert_equal expect, column_helper(review)
  end

  def test_column_2
    review =<<-EOS
===[column] test

inside column

=== next level
EOS
    expect =<<-EOS

\\begin{reviewcolumn}
\\reviewcolumnhead{}{test}

inside column

\\end{reviewcolumn}

\\subsection*{next level}
EOS

    assert_equal expect, column_helper(review)
  end

  def test_column_3
    review =<<-EOS
===[column] test

inside column

===[/column_dummy]
EOS
    assert_raise(ReVIEW::CompileError) do
      column_helper(review)
    end
  end
end
