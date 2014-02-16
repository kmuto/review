# -*- coding: utf-8 -*-
require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'
require 'review/i18n'

class LATEXBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = LATEXBuilder.new()
    @param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, EPUBBuilder
      "toclevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
      "stylesheet" => nil,  # for EPUBBuilder
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(nil, 1, 'chap1', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|\\chapter{this is test.}\n\\label{chap:chap1}\n|, @builder.result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|\\chapter*{this is test.}\n\\addcontentsline{toc}{chapter}{this is test.}\n\\label{chap:chap1}\n|, @builder.result
  end

  def test_headline_level1_with_inlinetag
    @builder.headline(1,"test","this @<b>{is} test.<&\"_>")
    assert_equal %Q|\\chapter{this \\textbf{is} test.\\textless{}\\&\"\\textunderscore{}\\textgreater{}}\n\\label{chap:chap1}\n|, @builder.result
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
    ret = @builder.compile_inline('@<href>{http://github.com,GitHub}')
    assert_equal %Q|\\href{http://github.com}{GitHub}|, ret
  end

  def test_inline_href
    ret = @builder.compile_inline('@<href>{http://github.com,Git\\,Hub}')
    assert_equal %Q|\\href{http://github.com}{Git,Hub}|, ret
  end

  def test_href_without_label
    ret = @builder.compile_inline('@<href>{http://github.com}')
    assert_equal %Q|\\url{http://github.com}|, ret
  end

  def test_href_with_underscore
    ret = @builder.compile_inline('@<href>{http://example.com/aaa/bbb, AAA_BBB}')
    assert_equal %Q|\\href{http://example.com/aaa/bbb}{AAA\\textunderscore{}BBB}|, ret
  end

  def test_href_mailto
    ret = @builder.compile_inline('@<href>{mailto:takahashim@example.com, takahashim@example.com}')
    assert_equal %Q|\\href{mailto:takahashim@example.com}{takahashim@example.com}|, ret
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
    assert_equal "@<tt>{inline!$%}", ret
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
    assert_equal %Q|abc\\reviewem{def}|, ret
  end

  def test_inline_strong
    ret = @builder.compile_inline("abc@<strong>{def}")
    assert_equal %Q|abc\\reviewstrong{def}|, ret
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
    assert_equal %Q|test \\texttt{in{-}line {-}{-}test {-}{-}{-}foo {-}{-}{-}{-}bar {-}{-}{-}{-}{-}buz} {-}{-}test2|, ret
  end

  def test_inline_tti
    ret = @builder.compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test \\texttt{\\textit{inline test}} test2|, ret
  end

  def test_inline_ttb
    ret = @builder.compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test \\texttt{\\textbf{inline test}} test2|, ret
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new("chap1|test", [1, 1], "te_st")]
      Book::HeadlineIndex.new(items, self)
    end

    ret = @builder.compile_inline("test @<hd>{chap1|test} test2")
    assert_equal %Q|test 「1.1.1 te\\textunderscore{}st」 test2|, ret
  end

  def test_inline_ruby_comma
    ret = @builder.compile_inline("@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}")
    assert_equal "\\ruby{foo, bar, buz}{フー・バー・バズ}", ret
  end

  def test_inline_uchar
    ret = @builder.compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test \\UTF{2460} test2|, ret
  end

  def test_jis_x_0201_kana
    ret = @builder.compile_inline("foo･ｶﾝｼﾞ､テスト")
    assert_equal %Q|foo\\aj半角{・}\\aj半角{カ}\\aj半角{ン}\\aj半角{シ}\\aj半角{゛}\\aj半角{、}テスト|, ret
  end

  def test_dlist
    @builder.dl_begin
    @builder.dt "foo"
    @builder.dd ["foo.\n", "bar.\n"]
    @builder.dl_end
    assert_equal %Q|\n\\begin{description}\n\\item[foo] \\mbox{} \\\\\nfoo.\nbar.\n\\end{description}\n|, @builder.result
  end

  def test_dlist_with_bracket
    @builder.dl_begin
    @builder.dt "foo[bar]"
    @builder.dd ["foo.\n", "bar.\n"]
    @builder.dl_end
    assert_equal %Q|\n\\begin{description}\n\\item[foo\\lbrack{}bar\\rbrack{}] \\mbox{} \\\\\nfoo.\nbar.\n\\end{description}\n|, @builder.result
  end

  def test_cmd
    lines = ["foo", "bar", "","buz"]
    @builder.cmd(lines)
    assert_equal %Q|\n\\begin{reviewcmd}\nfoo\nbar\n\nbuz\n\\end{reviewcmd}\n|, @builder.result
  end

  def test_cmd_caption
    lines = ["foo", "bar", "","buz"]
    @builder.cmd(lines, "cap1")
    assert_equal %Q|\n\\reviewcmdcaption{cap1}\n\\begin{reviewcmd}\nfoo\nbar\n\nbuz\n\\end{reviewcmd}\n|, @builder.result
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    @builder.list(["test1", "test1.5", "", "test<i>2</i>"], "samplelist", "this is @<b>{test}<&>_")

    assert_equal %Q|\\reviewlistcaption{リスト1.1: this is \\textbf{test}\\textless{}\\&\\textgreater{}\\textunderscore{}}\n\\begin{reviewlist}\ntest1\ntest1.5\n\ntest<i>2</i>\n\\end{reviewlist}\n\n|, @builder.raw_result
  end

  def test_emlist
    lines = ["foo", "bar", "","buz"]
    @builder.emlist(lines)
    assert_equal %Q|\n\\begin{reviewemlist}\nfoo\nbar\n\nbuz\n\\end{reviewemlist}\n|, @builder.result
  end

  def test_emlist_caption
    lines = ["foo", "bar", "","buz"]
    @builder.emlist(lines, "cap1")
    assert_equal %Q|\n\\reviewemlistcaption{cap1}\n\\begin{reviewemlist}\nfoo\nbar\n\nbuz\n\\end{reviewemlist}\n|, @builder.result
  end

  def test_emlist_with_tab
    lines = ["\tfoo", "\t\tbar", "","\tbuz"]
    @builder.emlist(lines)
    assert_equal %Q|\n\\begin{reviewemlist}\n        foo\n                bar\n\n        buz\n\\end{reviewemlist}\n|, @builder.result
  end

  def test_emlist_with_tab4
    lines = ["\tfoo", "\t\tbar", "","\tbuz"]
    @builder.instance_eval{@tabwidth=4}
    @builder.emlist(lines)
    assert_equal %Q|\n\\begin{reviewemlist}\n    foo\n        bar\n\n    buz\n\\end{reviewemlist}\n|, @builder.result
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

  def test_centering
    @builder.centering(["foo", "bar", "","buz"])
    assert_equal %Q|\n\\begin{center}\nfoobar\n\nbuz\n\\end{center}\n|, @builder.raw_result
  end

  def test_noindent
    @builder.noindent
    @builder.paragraph(["foo", "bar"])
    @builder.paragraph(["foo2", "bar2"])
    assert_equal %Q|\\noindent\nfoo\nbar\n\nfoo2\nbar2\n|, @builder.raw_result
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo",nil)
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo","scale=1.2, html::class=\"sample\", latex::height=3cm")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2,height=3cm]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo",nil)
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    @builder.indepimage("sampleimg",nil,nil)
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo","scale=1.2, latex::height=3cm, html::class=\"sample\"")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2,height=3cm]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    @builder.indepimage("sampleimg",nil,"scale=1.2")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n|, @builder.raw_result
  end

  def test_bib
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    assert_equal "\\reviewbibref{[1]}{bib:samplebib}", @builder.inline_bib("samplebib")
  end

  def test_bibpaper
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    @builder.bibpaper(["a", "b"], "samplebib", "sample bib @<b>{bold}")
    assert_equal %Q|[1] sample bib \\textbf{bold}\n\\label{bib:samplebib}\n\nab\n|, @builder.raw_result
  end

  def test_bibpaper_without_body
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    @builder.bibpaper([], "samplebib", "sample bib")
    assert_equal %Q|[1] sample bib\n\\label{bib:samplebib}\n\n|, @builder.raw_result
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

  def test_ul
    src =<<-EOS
  * AAA
  * BBB
EOS
    expect =<<-EOS

\\begin{itemize}
\\item AAA
\\item BBB
\\end{itemize}
EOS
    ul_helper(src, expect)
  end

  def test_ul_with_bracket
    src =<<-EOS
  * AAA
  * []BBB
EOS
    expect =<<-EOS

\\begin{itemize}
\\item AAA
\\item \\lbrack{}]BBB
\\end{itemize}
EOS
    ul_helper(src, expect)
  end

  def test_cont
    src =<<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS
    expect =<<-EOS

\\begin{itemize}
\\item AAA{-}AA
\\item BBB{-}BB
\\end{itemize}
EOS
    ul_helper(src, expect)
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
EOS

    expect =<<-EOS

\\begin{itemize}
\\item AAA

\\begin{itemize}
\\item AA
\\end{itemize}

\\end{itemize}
EOS
    ul_helper(src, expect)
  end

  def test_ul_nest3
    src =<<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expect =<<-EOS

\\begin{itemize}
\\item AAA

\\begin{itemize}
\\item AA
\\end{itemize}

\\item BBB

\\begin{itemize}
\\item BB
\\end{itemize}

\\end{itemize}
EOS
    ul_helper(src, expect)
  end

  def test_ol
    src =<<-EOS
  3. AAA
  3. BBB
EOS

    expect =<<-EOS

\\begin{enumerate}
\\item AAA
\\item BBB
\\end{enumerate}
EOS
    ol_helper(src, expect)
  end

  def test_ol_with_bracket
    src =<<-EOS
  1. AAA
  2. []BBB
EOS
    expect =<<-EOS

\\begin{enumerate}
\\item AAA
\\item \\lbrack{}]BBB
\\end{enumerate}
EOS
    builder_helper(src, expect, :compile_olist)
  end

  def test_inline_raw0
    assert_equal "normal", @builder.inline_raw("normal")
  end

  def test_inline_raw1
    assert_equal "body", @builder.inline_raw("|latex|body")
  end

  def test_inline_raw2
    assert_equal "body", @builder.inline_raw("|html, latex|body")
  end

  def test_inline_raw3
    assert_equal "", @builder.inline_raw("|idgxml, html|body")
  end

  def test_inline_raw4
    assert_equal "|latex body", @builder.inline_raw("|latex body")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", @builder.inline_raw("|latex|nor\\nmal")
  end

  def test_inline_endash
    ret = @builder.compile_inline("- -- --- ----")
    assert_equal "{-} {-}{-} {-}{-}{-} {-}{-}{-}{-}", ret
  end

  def test_block_raw0
    @builder.raw("<>!\"\\n& ")
    expect =<<-EOS
<>!"
& 
EOS
    assert_equal expect.chomp, @builder.raw_result
  end

  def test_block_raw1
    @builder.raw("|latex|<>!\"\\n& ")
    expect =<<-EOS
<>!"
& 
EOS
    assert_equal expect.chomp, @builder.raw_result
  end

  def test_block_raw2
    @builder.raw("|html, latex|<>!\"\\n& ")
    expect =<<-EOS
<>!\"
& 
EOS
    assert_equal expect.chomp, @builder.raw_result
  end

  def test_block_raw3
    @builder.raw("|html, idgxml|<>!\"\\n& ")
    expect =<<-EOS
EOS
    assert_equal expect.chomp, @builder.raw_result
  end

  def test_block_raw4
    @builder.raw("|latex <>!\"\\n& ")
    expect =<<-EOS
|latex <>!\"
& 
EOS
    assert_equal expect.chomp, @builder.raw_result
  end

end

begin
  #  test syntax highlighting when Pygments is available
  require 'pygments'

  class LATEXBuidlerWithPygmentsTest < Test::Unit::TestCase
    include ReVIEW

    def setup
      @builder = LATEXBuilder.new(false)
      @builder.highlighter = ReVIEW::Highlighter.new(:pygments, 'color')
      @param = {
        "secnolevel" => 2,    # for IDGXMLBuilder, EPUBBuilder
        "toclevel" => 2,
        "inencoding" => "UTF-8",
        "outencoding" => "UTF-8",
        "subdirmode" => nil,
        "stylesheet" => nil,  # for EPUBBuilder
      }
      ReVIEW.book.param = @param
      @compiler = ReVIEW::Compiler.new(@builder)
      @chapter = Book::Chapter.new(nil, 1, 'chap1', nil, StringIO.new)
      location = Location.new(nil, nil)
      @builder.bind(@compiler, @chapter, location)
    end

    def test_list
      def @chapter.list(id)
        Book::ListIndex::Item.new("samplelist",1)
      end
      @builder.list(["test1", "test1.5", "", "test<i>2</i>"], "samplelist", "this is @<b>{test}<&>_")

      assert_equal %Q|\\reviewlistcaption{リスト1.1: this is \\textbf{test}\\textless{}\\&\\textgreater{}\\textunderscore{}}\n\\begin{reviewlist}\n\\begin{Verbatim}[commandchars=\\\\\\{\\}]\ntest1\ntest1.5\n\ntest\\PY{n+nt}{\\PYZlt{}i}\\PY{n+nt}{\\PYZgt{}}2\\PY{n+nt}{\\PYZlt{}/i\\PYZgt{}}\n\\end{Verbatim}\n\\end{reviewlist}\n\n|, @builder.raw_result
    end
  end
rescue LoadError
end
