require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'
require 'review/i18n'

class LATEXBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = LATEXBuilder.new
    @config = ReVIEW::Configure.values
    @config.merge!(
      'secnolevel' => 2, # for IDGXMLBuilder, EPUBBuilder
      'toclevel' => 2,
      'stylesheet' => nil, # for EPUBBuilder
      'image_scale2width' => false,
      'texcommand' => 'uplatex'
    )
    @book = Book::Base.new(nil)
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, 'chap1', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup('ja')
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(\\chapter{this is test.}\n\\label{chap:chap1}\n), actual
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(\\chapter*{this is test.}\n\\addcontentsline{toc}{chapter}{this is test.}\n\\label{chap:chap1}\n), actual
  end

  def test_headline_level1_with_inlinetag
    actual = compile_block(%Q(={test} this @<b>{is} test.<&"_>\n))
    assert_equal %Q(\\chapter{this \\textbf{is} test.\\textless{}\\&"\\textunderscore{}\\textgreater{}}\n\\label{chap:chap1}\n), actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q(\\section{this is test.}\n\\label{sec:1-1}\n\\label{test}\n), actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(\\subsection*{this is test.}\n\\label{sec:1-0-1}\n\\label{test}\n), actual
  end

  def test_headline_level3_with_secno
    @config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(\\subsection{this is test.}\n\\label{sec:1-0-1}\n\\label{test}\n), actual
  end

  def test_label
    actual = compile_block("//label[label_test]\n")
    assert_equal %Q(\\label{label_test}\n), actual
  end

  def test_href
    actual = compile_inline('@<href>{http://github.com,GitHub}')
    assert_equal '\\href{http://github.com}{GitHub}', actual
  end

  def test_inline_href
    actual = compile_inline('@<href>{http://github.com,Git\\,Hub}')
    assert_equal '\\href{http://github.com}{Git,Hub}', actual
  end

  def test_href_without_label
    actual = compile_inline('@<href>{http://github.com}')
    assert_equal '\\url{http://github.com}', actual
  end

  def test_href_with_underscore
    actual = compile_inline('@<href>{http://example.com/aaa/bbb, AAA_BBB}')
    assert_equal '\\href{http://example.com/aaa/bbb}{AAA\\textunderscore{}BBB}', actual
  end

  def test_href_mailto
    actual = compile_inline('@<href>{mailto:takahashim@example.com, takahashim@example.com}')
    assert_equal '\\href{mailto:takahashim@example.com}{takahashim@example.com}', actual
  end

  def test_inline_br
    actual = compile_inline('@<br>{}')
    assert_equal %Q(\\\\\n), actual
  end

  def test_inline_br_with_other_strings
    actual = compile_inline('abc@<br>{}def')
    assert_equal %Q(abc\\\\\ndef), actual
  end

  def test_inline_i
    actual = compile_inline('abc@<i>{def}ghi')
    assert_equal 'abc\\textit{def}ghi', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test \\textit{inline\\textless{}\\&;\\reviewbackslash{} test} test2', actual
  end

  def test_inline_dtp
    actual = compile_inline('abc@<dtp>{def}ghi')
    assert_equal 'abcghi', actual
  end

  def test_inline_code
    actual = compile_inline('abc@<code>{def}ghi')
    assert_equal 'abc\\texttt{def}ghi', actual
  end

  def test_inline_raw
    actual = compile_inline('@<raw>{@<tt>{inline!$%\\}}')
    assert_equal '@<tt>{inline!$%}', actual
  end

  def test_inline_sup
    actual = compile_inline('abc@<sup>{def}')
    assert_equal 'abc\\textsuperscript{def}', actual
  end

  def test_inline_sub
    actual = compile_inline('abc@<sub>{def}')
    assert_equal 'abc\\textsubscript{def}', actual
  end

  def test_inline_b
    actual = compile_inline('abc@<b>{def}')
    assert_equal 'abc\\textbf{def}', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test \\textbf{inline\\textless{}\\&;\\reviewbackslash{} test} test2', actual
  end

  def test_inline_em
    actual = compile_inline('abc@<em>{def}')
    assert_equal 'abc\\reviewem{def}', actual
  end

  def test_inline_strong
    actual = compile_inline('abc@<strong>{def}')
    assert_equal 'abc\\reviewstrong{def}', actual
  end

  def test_inline_u
    actual = compile_inline('abc@<u>{def}ghi')
    assert_equal 'abc\\reviewunderline{def}ghi', actual
  end

  def test_inline_m
    actual = compile_inline('abc@<m>{\\alpha^n = \\inf < 2}ghi')
    assert_equal 'abc $\\alpha^n = \\inf < 2$ ghi', actual
  end

  def test_inline_m2
    ## target text: @<m>{X = \{ {x_1\},{x_2\}, \cdots ,{x_n\} \\\}}
    actual = compile_inline('@<m>{X = \\{ {x_1\\},{x_2\\}, \\cdots ,{x_n\\} \\\\\\}}')
    ## expected text: $X = \{ {x_1},{x_2}, \cdots ,{x_n} \}$
    assert_equal ' $X = \\{ {x_1},{x_2}, \\cdots ,{x_n} \\}$ ', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2')
    assert_equal 'test \\texttt{inline test} test2', actual
  end

  def test_inline_tt_endash
    actual = compile_inline('test @<tt>{in-line --test ---foo ----bar -----buz} --test2')
    assert_equal 'test \\texttt{in{-}line {-}{-}test {-}{-}{-}foo {-}{-}{-}{-}bar {-}{-}{-}{-}{-}buz} {-}{-}test2', actual
  end

  def test_inline_tti
    actual = compile_inline('test @<tti>{inline test} test2')
    assert_equal 'test \\texttt{\\textit{inline test}} test2', actual
  end

  def test_inline_ttb
    actual = compile_inline('test @<ttb>{inline test} test2')
    assert_equal 'test \\texttt{\\textbf{inline test}} test2', actual
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new('chap1|test', [1, 1], 'te_st')]
      Book::HeadlineIndex.new(items, self)
    end

    @config['secnolevel'] = 3
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test 「1.1.1 te\\textunderscore{}st」 test2', actual
  end

  def test_inline_pageref
    actual = compile_inline('test p.@<pageref>{p1}')
    assert_equal 'test p.\pageref{p1}', actual
  end

  def test_inline_ruby_comma
    actual = compile_inline('@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}')
    assert_equal '\\ruby{foo, bar, buz}{フー・バー・バズ}', actual
  end

  def test_inline_uchar
    actual = compile_inline('test @<uchar>{2460} test2')
    assert_equal 'test \\UTF{2460} test2', actual
  end

  def test_inline_idx
    actual = compile_inline('@<idx>{__TEST%$}, @<hidx>{__TEST%$}')
    assert_equal '\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}\\index{__TEST%$@\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}}, \\index{__TEST%$@\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}}', actual
  end

  def test_inline_idx_yomi
    begin
      require 'MeCab'
      require 'nkf'
    rescue LoadError
      $stderr.puts 'skip test_inline_idx_yomi (cannot find MeCab)'
      return true
    end
    tmpdir = Dir.mktmpdir
    File.write("#{tmpdir}/sample.dic", "強運\tはーどらっく\n")
    @book.config['pdfmaker']['makeindex'] = true
    @book.config['pdfmaker']['makeindex_dic'] = "#{tmpdir}/sample.dic"
    @builder.setup_index
    actual = compile_inline('@<hidx>{漢字}@<hidx>{強運}@<hidx>{項目@1<<>>項目@2}')
    FileUtils.remove_entry_secure(tmpdir)
    assert_equal %Q(\\index{かんじ@漢字}\\index{はーどらっく@強運}\\index{こうもく"@1@項目"@1!こうもく"@2@項目"@2}), actual
  end

  def test_jis_x_0201_kana
    # uplatex can handle half-width kana natively
    actual = compile_inline('foo･ｶﾝｼﾞ､テスト')
    assert_equal 'foo･ｶﾝｼﾞ､テスト', actual
    # assert_equal %Q(foo\\aj半角{・}\\aj半角{カ}\\aj半角{ン}\\aj半角{シ}\\aj半角{゛}\\aj半角{、}テスト), actual
  end

  def test_dlist
    actual = compile_block(": foo\n  foo.\n  bar.\n")
    assert_equal %Q(\n\\begin{description}\n\\item[foo] \\mbox{} \\\\\nfoo.bar.\n\\end{description}\n), actual
  end

  def test_dlist_with_bracket
    actual = compile_block(": foo[bar]\n    foo.\n    bar.\n")
    assert_equal %Q(\n\\begin{description}\n\\item[foo\\lbrack{}bar\\rbrack{}] \\mbox{} \\\\\nfoo.bar.\n\\end{description}\n), actual
  end

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    assert_equal %Q(\n\\begin{description}\n\\item[foo] \\mbox{} \\\\\nfoo.\n\\end{description}\n\npara\n\n\\begin{description}\n\\item[foo] \\mbox{} \\\\\nfoo.\n\\end{description}\n\n\\begin{enumerate}\n\\item bar\n\\end{enumerate}\n\n\\begin{description}\n\\item[foo] \\mbox{} \\\\\nfoo.\n\\end{description}\n\n\\begin{itemize}\n\\item bar\n\\end{itemize}\n), actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\begin{reviewcmd}\nfoo\nbar\n\nbuz\n\\end{reviewcmd}\n), actual
  end

  def test_cmd_caption
    actual = compile_block("//cmd[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\reviewcmdcaption{cap1}\n\\begin{reviewcmd}\nfoo\nbar\n\nbuz\n\\end{reviewcmd}\n), actual
  end

  def test_cmd_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//cmd{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\\vspace{-1.5em}\\begin{reviewcmdlst}[title={\\relax},language={}]\nfoo\nbar\n\nbuz\n\\end{reviewcmdlst}\n), actual
  end

  def test_emlist
    actual = compile_block("//emlist{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\begin{reviewemlist}\nfoo\nbar\n\nbuz\n\\end{reviewemlist}\n), actual
  end

  def test_emlist_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//emlist[][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    assert_equal %Q(\n\\vspace{-1.5em}\\begin{reviewemlistlst}[title={\\relax},language={sql}]\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n\\end{reviewemlistlst}\n), actual
  end

  def test_emlist_lst_without_lang
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    @book.config['highlight']['lang'] = 'sql'
    actual = compile_block("//emlist[]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    assert_equal %Q(\n\\vspace{-1.5em}\\begin{reviewemlistlst}[title={\\relax},language={sql}]\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n\\end{reviewemlistlst}\n), actual
  end

  def test_emlist_caption
    actual = compile_block("//emlist[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\reviewemlistcaption{cap1}\n\\begin{reviewemlist}\nfoo\nbar\n\nbuz\n\\end{reviewemlist}\n), actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist{\n\tfoo\n\t\tbar\n\n\tbuz\n//}\n")
    assert_equal %Q(\n\\begin{reviewemlist}\n        foo\n                bar\n\n        buz\n\\end{reviewemlist}\n), actual
  end

  def test_emlist_with_tab4
    @config['tabwidth'] = 4
    actual = compile_block("//emlist{\n\tfoo\n\t\tbar\n\n\tbuz\n//}\n")
    assert_equal %Q(\n\\begin{reviewemlist}\n    foo\n        bar\n\n    buz\n\\end{reviewemlist}\n), actual
  end

  def test_emlistnum_caption
    actual = compile_block("//emlistnum[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\reviewemlistcaption{cap1}\n\\begin{reviewemlist}\n 1: foo\n 2: bar\n 3: \n 4: buz\n\\end{reviewemlist}\n), actual
  end

  def test_list
    actual = compile_block("//list[id1][cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\\reviewlistcaption{リスト1.1: cap1}\n\\begin{reviewlist}\nfoo\nbar\n\nbuz\n\\end{reviewlist}\n), actual
  end

  def test_list_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//list[id1][cap1][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    assert_equal %Q(\\begin{reviewlistlst}[caption={cap1},language={sql}]\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n\\end{reviewlistlst}\n), actual
  end

  def test_list_lst_with_lang
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    @book.config['highlight']['lang'] = 'sql'
    actual = compile_block("//list[id1][cap1]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    assert_equal %Q(\\begin{reviewlistlst}[caption={cap1},language={sql}]\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n\\end{reviewlistlst}\n), actual
  end

  def test_listnum
    actual = compile_block("//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    assert_equal %Q(\\reviewlistcaption{リスト1.1: ruby}\n\\begin{reviewlist}\n 1: class Foo\n 2:   def foo\n 3:     bar\n 4: \n 5:     buz\n 6:   end\n 7: end\n\\end{reviewlist}\n), actual
  end

  def test_listnum_linenum
    actual = compile_block("//firstlinenum[100]\n//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    assert_equal %Q(\\reviewlistcaption{リスト1.1: ruby}\n\\begin{reviewlist}\n100: class Foo\n101:   def foo\n102:     bar\n103: \n104:     buz\n105:   end\n106: end\n\\end{reviewlist}\n), actual
  end

  def test_listnum_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    assert_equal %Q(\\begin{reviewlistnumlst}[caption={ruby},language={}]\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n\\end{reviewlistnumlst}\n), actual
  end

  def test_listnum_lst_linenum
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//firstlinenum[100]\n//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    assert_equal %Q(\\begin{reviewlistnumlst}[caption={ruby},language={},firstnumber=100]\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n\\end{reviewlistnumlst}\n), actual
  end

  def test_source
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\\reviewsourcecaption{foo/bar/test.rb}\n\\begin{reviewsource}\nfoo\nbar\n\nbuz\n\\end{reviewsource}\n), actual
  end

  def test_source_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\\begin{reviewsourcelst}[title={foo/bar/test.rb},language={}]\nfoo\nbar\n\nbuz\n\\end{reviewsourcelst}\n), actual
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\begin{quote}\nfoobar\n\nbuz\n\\end{quote}\n), actual
  end

  def test_memo
    actual = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(\\begin{reviewminicolumn}\n\\reviewminicolumntitle{this is \\textbf{test}\\textless{}\\&\\textgreater{}\\textunderscore{}}\ntest1\n\ntest\\textit{2}\n\\end{reviewminicolumn}\n), actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\begin{flushright}\nfoobar\n\nbuz\n\\end{flushright}\n), actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n\\begin{center}\nfoobar\n\nbuz\n\\end{center}\n), actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(\\noindent\nfoo\nbar\n\nfoo2\nbar2\n), actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n), actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n), actual
  end

  def test_image_with_metric_width
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    @config['image_scale2width'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[width=1.2\\maxwidth]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n), actual
  end

  def test_image_with_metric2
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[scale=1.2,ignore=params]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n), actual
  end

  def test_image_with_metric2_width
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    @config['image_scale2width'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[width=1.2\\maxwidth,ignore=params]{./images/chap1-sampleimg.png}\n\\caption{sample photo}\n\\label{image:chap1:sampleimg}\n\\end{reviewimage}\n), actual
  end

  def test_indepimage
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n), actual
  end

  def test_indepimage_without_caption
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    actual = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n), actual
  end

  def test_indepimage_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n), actual
  end

  def test_indepimage_with_metric_width
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    @config['image_scale2width'] = true
    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[width=1.2\\maxwidth]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n), actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block(%Q(//indepimage[sampleimg][sample photo][scale=1.2, html::class="sample",latex::ignore=params]\n))
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[scale=1.2,ignore=params]{./images/chap1-sampleimg.png}\n\\reviewindepimagecaption{図: sample photo}\n\\end{reviewimage}\n), actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q(\\begin{reviewimage}\n\\includegraphics[scale=1.2]{./images/chap1-sampleimg.png}\n\\end{reviewimage}\n), actual
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    assert_equal "\\begin{reviewtable}{|l|l|}\n\\hline\n\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline\nccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline\n\\end{reviewtable}\n",
                 actual
  end

  def test_customize_cellwidth
    actual = compile_block("//tsize[2,3,5]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(\\begin{reviewtable}{|p{2mm}|p{3mm}|p{5mm}|}\n\\hline\n\\reviewth{A} & B & C \\\\  \\hline\n\\end{reviewtable}\n), actual

    actual = compile_block("//tsize[|latex,html|2,3,5]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(\\begin{reviewtable}{|p{2mm}|p{3mm}|p{5mm}|}\n\\hline\n\\reviewth{A} & B & C \\\\  \\hline\n\\end{reviewtable}\n), actual

    actual = compile_block("//tsize[|html|2,3,5]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(\\begin{reviewtable}{|l|l|l|}\n\\hline\n\\reviewth{A} & B & C \\\\  \\hline\n\\end{reviewtable}\n), actual

    actual = compile_block("//tsize[|latex|2,3,5]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(\\begin{reviewtable}{|p{2mm}|p{3mm}|p{5mm}|}\n\\hline\n\\reviewth{A} & B & C \\\\  \\hline\n\\end{reviewtable}\n), actual

    actual = compile_block("//tsize[|latex||p{5mm}|cr|]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(\\begin{reviewtable}{|p{5mm}|cr|}\n\\hline\n\\reviewth{A} & B & C \\\\  \\hline\n\\end{reviewtable}\n), actual
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    assert_equal "\\begin{table}[h]\n\\reviewtablecaption*{foo}\n\\begin{reviewtable}{|l|l|}\n\\hline\n\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline\nccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline\n\\end{reviewtable}\n\\end{table}\n\n\\begin{reviewtable}{|l|l|}\n\\hline\n\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline\nccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline\n\\end{reviewtable}\n",
                 actual
  end

  def test_imgtable
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1, 'sample img')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")

    expected = <<-EOS
\\begin{table}[h]
\\reviewimgtablecaption{test for imgtable}
\\label{table:chap1:sampleimg}
\\begin{reviewimage}
\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
\\end{table}
EOS
    assert_equal expected, actual
  end

  def test_bib
    def @chapter.bibpaper(_id)
      Book::BibpaperIndex::Item.new('samplebib', 1, 'sample bib')
    end

    assert_equal '\\reviewbibref{[1]}{bib:samplebib}', compile_inline('@<bib>{samplebib}')
  end

  def test_bibpaper
    def @chapter.bibpaper(_id)
      Book::BibpaperIndex::Item.new('samplebib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    assert_equal %Q([1] sample bib \\textbf{bold}\n\\label{bib:samplebib}\n\nab\n\n), actual
  end

  def test_bibpaper_without_body
    def @chapter.bibpaper(_id)
      Book::BibpaperIndex::Item.new('samplebib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[samplebib][sample bib]\n")
    assert_equal %Q([1] sample bib\n\\label{bib:samplebib}\n\n), actual
  end

  def column_helper(review)
    compile_block(review)
  end

  def test_column_1
    review = <<-EOS
===[column] prev column

inside prev column

===[column] test

inside column

===[/column]
EOS
    expected = <<-EOS

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
    @config['toclevel'] = 3
    assert_equal expected, column_helper(review)
  end

  def test_column_2
    review = <<-EOS
===[column] test

inside column

=== next level
EOS
    expected = <<-EOS

\\begin{reviewcolumn}
\\hypertarget{column:chap1:1}{}
\\reviewcolumnhead{}{test}

inside column

\\end{reviewcolumn}

\\subsection*{next level}
\\label{sec:1-0-1}
EOS

    @config['toclevel'] = 1
    assert_equal expected, column_helper(review)
  end

  def test_column_3
    review = <<-EOS
===[column] test

inside column

===[/column_dummy]
EOS
    assert_raise(ReVIEW::ApplicationError) do
      column_helper(review)
    end
  end

  def test_ul
    src = <<-EOS
  * AAA
  * BBB
EOS
    expected = <<-EOS

\\begin{itemize}
\\item AAA
\\item BBB
\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_with_bracket
    src = <<-EOS
  * AAA
  * []BBB
EOS
    expected = <<-EOS

\\begin{itemize}
\\item AAA
\\item \\lbrack{}]BBB
\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_cont
    src = <<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS
    expected = <<-EOS

\\begin{itemize}
\\item AAA{-}AA
\\item BBB{-}BB
\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest1
    src = <<-EOS
  * AAA
  ** AA
EOS

    expected = <<-EOS

\\begin{itemize}
\\item AAA

\\begin{itemize}
\\item AA
\\end{itemize}

\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest3
    src = <<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expected = <<-EOS

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
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ol
    src = <<-EOS
  3. AAA
  3. BBB
EOS

    expected = <<-EOS

\\begin{enumerate}
\\item AAA
\\item BBB
\\end{enumerate}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ol_with_bracket
    src = <<-EOS
  1. AAA
  2. []BBB
EOS
    expected = <<-EOS

\\begin{enumerate}
\\item AAA
\\item \\lbrack{}]BBB
\\end{enumerate}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = %Q(\\begin{reviewminicolumn}\nA\n\nB\n\\end{reviewminicolumn}\n\\begin{reviewminicolumn}\n\\reviewminicolumntitle{caption}\nA\n\\end{reviewminicolumn}\n)
    assert_equal expected, actual
  end

  def test_inline_raw0
    assert_equal 'normal', compile_inline('@<raw>{normal}')
  end

  def test_inline_raw1
    assert_equal 'body', compile_inline('@<raw>{|latex|body}')
  end

  def test_inline_raw2
    assert_equal 'body', compile_inline('@<raw>{|html, latex|body}')
  end

  def test_inline_raw3
    assert_equal '', compile_inline('@<raw>{|idgxml, html|body}')
  end

  def test_inline_raw4
    assert_equal '|latex body', compile_inline('@<raw>{|latex body}')
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline('@<raw>{|latex|nor\\nmal}')
  end

  def test_inline_endash
    actual = compile_inline('- -- --- ----')
    assert_equal '{-} {-}{-} {-}{-}{-} {-}{-}{-}{-}', actual
  end

  def test_inline_imgref
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1, 'sample photo')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block "@<imgref>{sampleimg}\n"
    expected = "\n\\reviewimageref{1.1}{image:chap1:sampleimg}「sample photo」\n"
    assert_equal expected, actual
  end

  def test_inline_imgref2
    def @chapter.image(_id)
      item = Book::NumberlessImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block "@<imgref>{sampleimg}\n"
    expected = "\n\\reviewimageref{1.1}{image:chap1:sampleimg}\n"
    assert_equal expected, actual
  end

  def test_block_raw0
    actual = compile_block(%Q(//raw[<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw1
    actual = compile_block(%Q(//raw[|latex|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw2
    actual = compile_block(%Q(//raw[|html, latex|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw3
    actual = compile_block(%Q(//raw[|html, idgxml|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw4
    actual = compile_block(%Q(//raw[|latex <>!"\\n& ]\n))
    expected = %Q(|latex <>!"\n& )
    assert_equal expected, actual
  end

  def test_comment
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント]')
    assert_equal %Q(\\pdfcomment{コメント}\n), actual
  end

  def test_inline_comment
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test  test2', actual
  end

  def test_inline_comment_for_draft
    @config['draft'] = true
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test \\pdfcomment{コメント} test2', actual
  end

  def test_inline_fence
    actual = compile_inline('test @<code>|@<code>{$サンプル$}|')
    assert_equal 'test \\texttt{@\\textless{}code\\textgreater{}\\{\\textdollar{}サンプル\\textdollar{}\\}}', actual
  end

  def test_appendix_list
    @chapter.instance_eval do
      def on_appendix?
        true
      end
    end
    src = <<-EOS
@<list>{foo}
//list[foo][FOO]{
//}
EOS
    expected = <<-EOS

\\reviewlistref{A.1}

\\reviewlistcaption{リストA.1: FOO}
\\begin{reviewlist}
\\end{reviewlist}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_appendix_table
    @chapter.instance_eval do
      def on_appendix?
        true
      end
    end
    src = <<-EOS
@<table>{foo}
//table[foo][FOO]{
A	B
//}
EOS
    expected = <<-EOS

\\reviewtableref{A.1}{table:chap1:foo}

\\begin{table}[h]
\\reviewtablecaption{FOO}
\\label{table:chap1:foo}
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{A} & B \\\\  \\hline
\\end{reviewtable}
\\end{table}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_appendix_image
    @chapter.instance_eval do
      def on_appendix?
        true
      end
    end

    def @chapter.image(_id)
      item = Book::NumberlessImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    src = <<-EOS
@<img>{sampleimg}
//image[sampleimg][FOO]{
//}
EOS
    expected = <<-EOS

\\reviewimageref{A.1}{image:chap1:sampleimg}

\\begin{reviewimage}
\\includegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\caption{FOO}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end
end
