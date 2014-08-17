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
    @config = {
      "secnolevel" => 2,    # for IDGXMLBuilder, EPUBBuilder
      "toclevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "stylesheet" => nil,  # for EPUBBuilder
    }
    ReVIEW.book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(Book::Base.new(nil), 1, 'chap1', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|\\chapter{this is test.}\n\\label{chap:chap1}\n|, result
  end

  def test_headline_level1_without_secno
    @config["secnolevel"] = 0
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|\\chapter*{this is test.}\n\\addcontentsline{toc}{chapter}{this is test.}\n\\label{chap:chap1}\n|, result
  end

  def test_headline_level1_with_inlinetag
    result = compile_block("={test} this @<b>{is} test.<&\"_>\n")
    assert_equal %Q|\\chapter{this \\textbf{is} test.\\textless{}\\&\"\\textunderscore{}\\textgreater{}}\n\\label{chap:chap1}\n|, result
  end

  def test_headline_level2
    result = compile_block("=={test} this is test.\n")
    assert_equal %Q|\\section{this is test.}\n\\label{sec:1-1}\n|, result
  end

  def test_headline_level3
    result = compile_block("==={test} this is test.\n")
    assert_equal %Q|\\subsection*{this is test.}\n\\label{sec:1-0-1}\n|, result
  end


  def test_headline_level3_with_secno
    @config["secnolevel"] = 3
    result = compile_block("==={test} this is test.\n")
    assert_equal %Q|\\subsection{this is test.}\n\\label{sec:1-0-1}\n|, result
  end

  def test_label
    result = compile_block("//label[label_test]\n")
    assert_equal %Q|\\label{label_test}\n|, result
  end

  def test_href
    result = compile_inline("@<href>{http://github.com,GitHub}")
    assert_equal %Q|\\href{http://github.com}{GitHub}|, result
  end

  def test_inline_href
    result = compile_inline('@<href>{http://github.com,Git\\,Hub}')
    assert_equal %Q|\\href{http://github.com}{Git,Hub}|, result
  end

  def test_href_without_label
    result = compile_inline('@<href>{http://github.com}')
    assert_equal %Q|\\url{http://github.com}|, result
  end

  def test_href_with_underscore
    result = compile_inline('@<href>{http://example.com/aaa/bbb, AAA_BBB}')
    assert_equal %Q|\\href{http://example.com/aaa/bbb}{AAA\\textunderscore{}BBB}|, result
  end

  def test_href_mailto
    result = compile_inline('@<href>{mailto:takahashim@example.com, takahashim@example.com}')
    assert_equal %Q|\\href{mailto:takahashim@example.com}{takahashim@example.com}|, result
  end

  def test_inline_br
    result = compile_inline("@<br>{}")
    assert_equal %Q|\\\\\n|, result
  end

  def test_inline_br_with_other_strings
    result = compile_inline("abc@<br>{}def")
    assert_equal %Q|abc\\\\\ndef|, result
  end

  def test_inline_i
    result = compile_inline("abc@<i>{def}ghi")
    assert_equal %Q|abc\\textit{def}ghi|, result
  end

  def test_inline_i_and_escape
    result = compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test \\textit{inline\\textless{}\\&;\\reviewbackslash{} test} test2|, result
  end

  def test_inline_dtp
    result = compile_inline("abc@<dtp>{def}ghi")
    assert_equal %Q|abcghi|, result
  end

  def test_inline_code
    result = compile_inline("abc@<code>{def}ghi")
    assert_equal %Q|abc\\texttt{def}ghi|, result
  end

  def test_inline_raw
    result = compile_inline("@<raw>{@<tt>{inline!$%\\}}")
    assert_equal "@<tt>{inline!$%}", result
  end

  def test_inline_sup
    result = compile_inline("abc@<sup>{def}")
    assert_equal %Q|abc\\textsuperscript{def}|, result
  end

  def test_inline_sub
    result = compile_inline("abc@<sub>{def}")
    assert_equal %Q|abc\\textsubscript{def}|, result
  end

  def test_inline_b
    result = compile_inline("abc@<b>{def}")
    assert_equal %Q|abc\\textbf{def}|, result
  end

  def test_inline_b_and_escape
    result = compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test \\textbf{inline\\textless{}\\&;\\reviewbackslash{} test} test2|, result
  end
  def test_inline_em
    result = compile_inline("abc@<em>{def}")
    assert_equal %Q|abc\\reviewem{def}|, result
  end

  def test_inline_strong
    result = compile_inline("abc@<strong>{def}")
    assert_equal %Q|abc\\reviewstrong{def}|, result
  end

  def test_inline_u
    result = compile_inline("abc@<u>{def}ghi")
    assert_equal %Q|abc\\Underline{def}ghi|, result
  end

  def test_inline_m
    result = compile_inline("abc@<m>{\\alpha^n = \inf < 2}ghi")
    assert_equal "abc $\\alpha^n = inf < 2$ ghi", result
  end

  def test_inline_tt
    result = compile_inline("test @<tt>{inline test} test2")
    assert_equal %Q|test \\texttt{inline test} test2|, result
  end

  def test_inline_tt_endash
    result = compile_inline("test @<tt>{in-line --test ---foo ----bar -----buz} --test2")
    assert_equal %Q|test \\texttt{in{-}line {-}{-}test {-}{-}{-}foo {-}{-}{-}{-}bar {-}{-}{-}{-}{-}buz} {-}{-}test2|, result
  end

  def test_inline_tti
    result = compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test \\texttt{\\textit{inline test}} test2|, result
  end

  def test_inline_ttb
    result = compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test \\texttt{\\textbf{inline test}} test2|, result
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new("chap1|test", [1, 1], "te_st")]
      Book::HeadlineIndex.new(items, self)
    end

    @config["secnolevel"] = 3
    result = compile_inline("test @<hd>{chap1|test} test2")
    assert_equal %Q|test 「1.1.1 te\\textunderscore{}st」 test2|, result
  end

  def test_inline_ruby_comma
    result = compile_inline("@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}")
    assert_equal "\\ruby{foo, bar, buz}{フー・バー・バズ}", result
  end

  def test_inline_uchar
    result = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test \\UTF{2460} test2|, result
  end

  def test_inline_idx
    result = compile_inline("@<idx>{__TEST%$}, @<hidx>{__TEST%$}")
    assert_equal %Q|\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}\\index{__TEST%$}, \\index{__TEST%$}|, result
  end

  def test_jis_x_0201_kana
    result = compile_inline("foo･ｶﾝｼﾞ､テスト")
    assert_equal %Q|foo\\aj半角{・}\\aj半角{カ}\\aj半角{ン}\\aj半角{シ}\\aj半角{゛}\\aj半角{、}テスト|, result
  end

  def test_dlist
    result = compile_block(": foo\n  foo.\n  bar.\n")
    assert_equal %Q|\n\\begin{description}\n\\item[foo] \\mbox{} \\\\\nfoo.bar.\n\\end{description}\n|, result
  end

  def test_dlist_with_bracket
    result = compile_block(": foo[bar]\n    foo.\n    bar.\n")
    assert_equal %Q|\n\\begin{description}\n\\item[foo\\lbrack{}bar\\rbrack{}] \\mbox{} \\\\\nfoo.bar.\n\\end{description}\n|, result
  end

  def test_cmd
    result = compile_block("//cmd{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\begin{reviewcmd}\nfoo\nbar\n\nbuz\n\\end{reviewcmd}\n|, result
  end

  def test_cmd_caption
    result = compile_block("//cmd[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\reviewcmdcaption{cap1}\n\\begin{reviewcmd}\nfoo\nbar\n\nbuz\n\\end{reviewcmd}\n|, result
  end

  def test_emlist
    result = compile_block("//emlist{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\begin{reviewemlist}\nfoo\nbar\n\nbuz\n\\end{reviewemlist}\n|, result
  end

  def test_emlist_caption
    result = compile_block("//emlist[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\reviewemlistcaption{cap1}\n\\begin{reviewemlist}\nfoo\nbar\n\nbuz\n\\end{reviewemlist}\n|, result
  end

  def test_emlist_with_tab
    result = compile_block("//emlist{\n\tfoo\n\t\tbar\n\n\tbuz\n//}\n")
    assert_equal %Q|\n\\begin{reviewemlist}\n        foo\n                bar\n\n        buz\n\\end{reviewemlist}\n|, result
  end

  def test_emlist_with_tab4
    @config["tabwidth"] = 4
    result = compile_block("//emlist{\n\tfoo\n\t\tbar\n\n\tbuz\n//}\n")
    assert_equal %Q|\n\\begin{reviewemlist}\n    foo\n        bar\n\n    buz\n\\end{reviewemlist}\n|, result
  end

  def test_quote
    result = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\begin{quote}\nfoobar\n\nbuz\n\\end{quote}\n|, result
  end

  def test_memo
    result = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}")
    assert_equal %Q|\\begin{reviewminicolumn}\n\\reviewminicolumntitle{this is \\textbf{test}\\textless{}\\&\\textgreater{}\\textunderscore{}}\ntest1\n\ntest\\textit{2}\n\\end{reviewminicolumn}\n|, result
  end

  def test_flushright
    result = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\begin{flushright}\nfoobar\n\nbuz\n\\end{flushright}\n|, result
  end

  def test_centering
    result = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|\n\\begin{center}\nfoobar\n\nbuz\n\\end{center}\n|, result
  end

  def test_noindent
    result = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q|\\noindent\nfoo\nbar\n\nfoo2\nbar2\n|, result
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n|, result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n|, result
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2,ignore=params]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n|, result
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n|, result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    result = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n|, result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n|, result
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo][scale=1.2, html::class=\"sample\",latex::ignore=params]\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2,ignore=params]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n|, result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    result = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q|\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n|, result
  end

  def test_bib
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    assert_equal "\\reviewbibref{[1]}{bib:samplebib}", compile_inline("@<bib>{samplebib}")
  end

  def test_bibpaper
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    result = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    assert_equal %Q|[1] sample bib \\textbf{bold}\n\\label{bib:samplebib}\n\nab\n\n|, result
  end

  def test_bibpaper_without_body
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    result = compile_block("//bibpaper[samplebib][sample bib]\n")
    assert_equal %Q|[1] sample bib\n\\label{bib:samplebib}\n\n|, result
  end

  def column_helper(review)
    compile_block(review)
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
\\hypertarget{column:chap1:1}{}
\\reviewcolumnhead{}{prev column}
\\addcontentsline{toc}{subsection}{prev column}

inside prev column

\\end{reviewcolumn}

\\begin{reviewcolumn}
\\hypertarget{column:chap1:2}{}
\\reviewcolumnhead{}{test}
\\addcontentsline{toc}{subsection}{test}

inside column

\\end{reviewcolumn}
EOS
    @config["toclevel"] = 3
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
\\hypertarget{column:chap1:1}{}
\\reviewcolumnhead{}{test}

inside column

\\end{reviewcolumn}

\\subsection*{next level}
\\label{sec:1-0-1}
EOS

    @config["toclevel"] = 1
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
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_inline_raw0
    assert_equal "normal", compile_inline("@<raw>{normal}")
  end

  def test_inline_raw1
    assert_equal "body", compile_inline("@<raw>{|latex|body}")
  end

  def test_inline_raw2
    assert_equal "body", compile_inline("@<raw>{|html, latex|body}")
  end

  def test_inline_raw3
    assert_equal "", compile_inline("@<raw>{|idgxml, html|body}")
  end

  def test_inline_raw4
    assert_equal "|latex body", compile_inline("@<raw>{|latex body}")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline("@<raw>{|latex|nor\\nmal}")
  end

  def test_inline_endash
    result = compile_inline("- -- --- ----")
    assert_equal "{-} {-}{-} {-}{-}{-} {-}{-}{-}{-}", result
  end

  def test_block_raw0
    result = compile_inline("@<raw>{<>!\"\\n& }")
    expect = %Q(<>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw1
    result = compile_inline("@<raw>{|latex|<>!\"\\n& }")
    expect = %Q(<>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw2
    result = compile_inline("@<raw>{|html, latex|<>!\"\\n& }")
    expect = %Q(<>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw3
    result = compile_inline("@<raw>{|html, idgxml|<>!\"\\n& }")
    expect = ''
    assert_equal expect, result
  end

  def test_block_raw4
    result = compile_inline("@<raw>{|latex <>!\"\\n& }")
    expect = %Q(|latex <>!\"\n& )
    assert_equal expect, result
  end

end
