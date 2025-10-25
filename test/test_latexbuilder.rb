# frozen_string_literal: true

require_relative 'test_helper'
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
      'texcommand' => 'uplatex',
      'review_version' => '4'
    )
    @config['pdfmaker']['image_scale2width'] = nil
    @book = Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, 'chap1', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup('ja')
  end

  def test_escape
    actual = @builder.escape('<>&_')
    assert_equal %Q(\\textless{}\\textgreater{}\\&\\textunderscore{}), actual
  end

  def test_unescape
    actual = @builder.unescape(%Q(\\textless{}\\textgreater{}\\&\\textunderscore{}))
    assert_equal '<>&_', actual
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    expected = <<-EOS
\\chapter{this is test.}
\\label{chap:chap1}
EOS
    assert_equal expected, actual
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    expected = <<-EOS
\\chapter*{this is test.}
\\addcontentsline{toc}{chapter}{this is test.}
\\label{chap:chap1}
EOS
    assert_equal expected, actual
  end

  def test_headline_level1_with_inlinetag
    actual = compile_block(%Q(={test} this @<b>{is} test.<&"_>\n))
    expected = <<-EOS
\\chapter{this \\reviewbold{is} test.\\textless{}\\&"\\textunderscore{}\\textgreater{}}
\\label{chap:chap1}
EOS
    assert_equal expected, actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    expected = <<-EOS
\\section{this is test.}
\\label{sec:1-1}
\\label{test}
EOS
    assert_equal expected, actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    expected = <<-EOS
\\subsection*{this is test.}
\\label{sec:1-0-1}
\\label{test}
EOS
    assert_equal expected, actual
  end

  def test_headline_level3_with_secno
    @config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    expected = <<-EOS
\\subsection{this is test.}
\\label{sec:1-0-1}
\\label{test}
EOS
    assert_equal expected, actual
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

  def test_href_internal_with_label
    actual = compile_inline('@<href>{#inlineop, inline operations}')
    assert_equal '\\hyperref[inlineop]{inline operations}', actual
  end

  def test_href_internal_without_label
    actual = compile_inline('@<href>{#inlineop}')
    assert_equal '\\hyperref[inlineop]{\\#inlineop}', actual
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
    assert_equal 'abc\\reviewit{def}ghi', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test \\reviewit{inline\\textless{}\\&;\\reviewbackslash{} test} test2', actual
  end

  def test_inline_dtp
    actual = compile_inline('abc@<dtp>{def}ghi')
    assert_equal 'abcghi', actual
  end

  def test_inline_code
    actual = compile_inline('abc@<code>{def}ghi')
    assert_equal 'abc\\reviewcode{def}ghi', actual
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
    assert_equal 'abc\\reviewbold{def}', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test \\reviewbold{inline\\textless{}\\&;\\reviewbackslash{} test} test2', actual
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

  def test_inline_ins
    actual = compile_inline('abc@<ins>{def}ghi')
    assert_equal 'abc\\reviewinsert{def}ghi', actual
  end

  def test_inline_del
    actual = compile_inline('abc@<del>{def}ghi')
    assert_equal 'abc\\reviewstrike{def}ghi', actual
  end

  def test_inline_bou
    actual = compile_inline('傍点の@<bou>{テスト}です。')
    assert_equal '傍点の\\reviewbou{テスト}です。', actual
  end

  def test_inline_m
    @config['review_version'] = '3.0'
    actual = compile_inline('abc@<m>{\\alpha^n = \\inf < 2}ghi')
    assert_equal 'abc$\\alpha^n = \\inf < 2$ghi', actual

    @config['review_version'] = '2.0'
    actual = compile_inline('abc@<m>{\\alpha^n = \\inf < 2}ghi')
    assert_equal 'abc $\\alpha^n = \\inf < 2$ ghi', actual
  end

  def test_inline_m2
    @config['review_version'] = '3.0'
    ## target text: @<m>{X = \{ {x_1\},{x_2\}, \cdots ,{x_n\} \\\}}
    actual = compile_inline('@<m>{X = \\{ {x_1\\},{x_2\\}, \\cdots ,{x_n\\} \\\\\\}}')
    ## expected text: $X = \{ {x_1},{x_2}, \cdots ,{x_n} \}$
    assert_equal '$X = \\{ {x_1},{x_2}, \\cdots ,{x_n} \\}$', actual

    @config['review_version'] = '2.0'
    actual = compile_inline('@<m>{X = \\{ {x_1\\},{x_2\\}, \\cdots ,{x_n\\} \\\\\\}}')
    ## expected text: $X = \{ {x_1},{x_2}, \cdots ,{x_n} \}$
    assert_equal ' $X = \\{ {x_1},{x_2}, \\cdots ,{x_n} \\}$ ', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2')
    assert_equal 'test \\reviewtt{inline test} test2', actual
  end

  def test_inline_tt_endash
    actual = compile_inline('test @<tt>{in-line --test ---foo ----bar -----buz} --test2')
    assert_equal 'test \\reviewtt{in{-}line {-}{-}test {-}{-}{-}foo {-}{-}{-}{-}bar {-}{-}{-}{-}{-}buz} {-}{-}test2', actual
  end

  def test_inline_tti
    actual = compile_inline('test @<tti>{inline test} test2')
    assert_equal 'test \\reviewtti{inline test} test2', actual
  end

  def test_inline_ttb
    actual = compile_inline('test @<ttb>{inline test} test2')
    assert_equal 'test \\reviewttb{inline test} test2', actual
  end

  def test_endnote
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//endnote[foo][bar]\n\n@<endnote>{foo}\n") }
    assert_equal ':4: //endnote is found but //printendnotes is not found.', e.message

    actual = compile_block("@<endnote>{foo}\n//endnote[foo][bar]\n//printendnotes\n")
    expected = <<-'EOS'

\endnote{bar}

\theendnotes
EOS
    assert_equal expected, actual
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      item = Book::Index::Item.new('chap1|test', [1, 1], 'te_st')
      idx = Book::HeadlineIndex.new(self)
      idx.add_item(item)
      idx
    end

    @config['secnolevel'] = 3
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test \reviewsecref{「1.1.1 te\\textunderscore{}st」}{sec:1-1-1} test2', actual

    @config['chapterlink'] = nil
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test 「1.1.1 te\\textunderscore{}st」 test2', actual
  end

  def test_inline_sec
    def @chapter.headline_index
      item = Book::Index::Item.new('chap1|test', [1, 1], 'te_st<>')
      idx = Book::HeadlineIndex.new(self)
      idx.add_item(item)
      idx
    end

    @config['secnolevel'] = 3
    actual = compile_inline('test @<secref>{test}')
    assert_equal 'test \reviewsecref{「1.1.1 te\textunderscore{}st\textless{}\textgreater{}」}{sec:1-1-1}', actual
    actual = compile_inline('test @<sectitle>{test}')
    assert_equal 'test \reviewsecref{te\textunderscore{}st\textless{}\textgreater{}}{sec:1-1-1}', actual
    actual = compile_inline('test @<sec>{test}')
    assert_equal 'test \reviewsecref{1.1.1}{sec:1-1-1}', actual

    @config['secnolevel'] = 2
    actual = compile_inline('test @<secref>{test}')
    assert_equal 'test \reviewsecref{「te\textunderscore{}st\textless{}\textgreater{}」}{sec:1-1-1}', actual
    actual = compile_inline('test @<sectitle>{test}')
    assert_equal 'test \reviewsecref{te\textunderscore{}st\textless{}\textgreater{}}{sec:1-1-1}', actual
    assert_raises(ReVIEW::ApplicationError) { compile_block('test @<sec>{test}') }
    assert_match(/the target headline doesn't have a number/, @log_io.string)

    @config['chapterlink'] = nil
    @config['secnolevel'] = 3
    actual = compile_inline('test @<secref>{test}')
    assert_equal 'test 「1.1.1 te\textunderscore{}st\textless{}\textgreater{}」', actual
    actual = compile_inline('test @<sectitle>{test}')
    assert_equal 'test te\textunderscore{}st\textless{}\textgreater{}', actual
    actual = compile_inline('test @<sec>{test}')
    assert_equal 'test 1.1.1', actual
  end

  def test_inline_pageref
    actual = compile_inline('test p.@<pageref>{p1}')
    assert_equal 'test p.\pageref{p1}', actual
  end

  def test_inline_ruby
    actual = compile_inline('@<ruby>{  foo  ,  bar  }')
    assert_equal '\\ruby{foo}{bar}', actual
  end

  def test_inline_ruby_comma
    actual = compile_inline('@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}')
    assert_equal '\\ruby{foo, bar, buz}{フー・バー・バズ}', actual

    actual = compile_inline('@<ruby>{foo\\, bar\\, buz    ,  フー・バー・バズ  }')
    assert_equal '\\ruby{foo, bar, buz}{フー・バー・バズ}', actual
  end

  def test_inline_uchar
    actual = compile_inline('test @<uchar>{2460} test2')
    assert_equal 'test ① test2', actual
  end

  def test_inline_balloon
    actual = compile_inline('test @<balloon>{①}')
    assert_equal 'test \\reviewballoon{①}', actual
  end

  def test_inline_idx
    actual = compile_inline('@<idx>{__TEST%$}, @<hidx>{__TEST%$}')
    assert_equal '\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}\\index{__TEST%$@\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}}, \\index{__TEST%$@\\textunderscore{}\\textunderscore{}TEST\\%\\textdollar{}}', actual
  end

  def test_inline_idx_yomi
    require 'nkf'
    begin
      require 'MeCab'
    rescue LoadError
      begin
        require 'mecab'
      rescue LoadError
        $stderr.puts 'skip test_inline_idx_yomi (cannot find MeCab)'
        return true
      end
    end
    tmpdir = Dir.mktmpdir
    File.write(File.join(tmpdir, 'sample.dic'), "強運\tはーどらっく\nmain（ブロック）\tmain{|}\n")
    @book.config['pdfmaker']['makeindex'] = true
    @book.config['pdfmaker']['makeindex_dic'] = "#{tmpdir}/sample.dic"
    @builder.setup_index
    actual = compile_inline('@<hidx>{漢字}@<hidx>{強運}@<hidx>{項目@1<<>>項目@2}')
    assert_equal %Q(\\index{かんじ@漢字}\\index{はーどらっく@強運}\\index{こうもく"@1@項目"@1!こうもく"@2@項目"@2}), actual
    actual = compile_inline('@<hidx>{main（ブロック）}@<hidx>{あいうえお{\}}')
    FileUtils.remove_entry_secure(tmpdir)
    assert_equal %Q(\\index{main｛｜｝@main（ブロック）}\\index{あいうえお｛｝@あいうえお\\reviewleftcurlybrace{}\\reviewrightcurlybrace{}}), actual
  end

  def test_inline_idx_escape
    # as is
    %w[a あ ' ( ) = ` + ; * : , . ? /].each do |c|
      actual = @builder.index(c)
      assert_equal %Q(\\index{#{c}}), actual
    end
    actual = @builder.index('[')
    assert_equal %Q(\\index{[}), actual
    actual = @builder.index(']')
    assert_equal %Q(\\index{]}), actual

    # escape display string by "
    %w[! " @].each do |c|
      actual = @builder.index(c)
      assert_equal %Q(\\index{"#{c}@"#{c}}), actual
    end

    # escape display string by \
    %w[# % &].each do |c|
      actual = @builder.index(c)
      assert_equal %Q(\\index{#{c}@\\#{c}}), actual
    end

    # escape display string by macro
    actual = @builder.index('$')
    assert_equal %Q(\\index{$@\\textdollar{}}), actual
    actual = @builder.index('-')
    assert_equal %Q(\\index{-@{-}}), actual
    actual = @builder.index('~')
    assert_equal %Q(\\index{~@\\textasciitilde{}}), actual
    actual = @builder.index('^')
    assert_equal %Q(\\index{^@\\textasciicircum{}}), actual
    actual = @builder.index('\\')
    assert_equal %Q(\\index{\\@\\reviewbackslash{}}), actual
    actual = @builder.index('<')
    assert_equal %Q(\\index{<@\\textless{}}), actual
    actual = @builder.index('>')
    assert_equal %Q(\\index{>@\\textgreater{}}), actual
    actual = @builder.index('_')
    assert_equal %Q(\\index{_@\\textunderscore{}}), actual

    # escape both sort key and display string
    actual = @builder.index('{')
    assert_equal %Q(\\index{｛@\\reviewleftcurlybrace{}}), actual
    actual = @builder.index('|')
    assert_equal %Q(\\index{｜@\\textbar{}}), actual
    actual = @builder.index('}')
    assert_equal %Q(\\index{｝@\\reviewrightcurlybrace{}}), actual
  end

  def test_jis_x_0201_kana
    # uplatex can handle half-width kana natively
    actual = compile_inline('foo･ｶﾝｼﾞ､テスト')
    assert_equal 'foo･ｶﾝｼﾞ､テスト', actual
    # assert_equal %Q(foo\\aj半角{・}\\aj半角{カ}\\aj半角{ン}\\aj半角{シ}\\aj半角{゛}\\aj半角{、}テスト), actual
  end

  def test_dlist
    actual = compile_block(" : foo\n  foo.\n  bar.\n")
    expected = <<-EOS

\\begin{description}
\\item[foo] \\mbox{} \\\\
foo.
bar.
\\end{description}
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block(" : foo\n  foo.\n  bar.\n")
    expected = <<-EOS

\\begin{description}
\\item[foo] \\mbox{} \\\\
foo. bar.
\\end{description}
EOS
    assert_equal expected, actual
  end

  def test_dlist_with_bracket
    actual = compile_block(" : foo[bar]\n    foo.\n    bar.\n")
    expected = <<-EOS

\\begin{description}
\\item[foo\\lbrack{}bar\\rbrack{}] \\mbox{} \\\\
foo.
bar.
\\end{description}
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block(" : foo[bar]\n    foo.\n    bar.\n")
    expected = <<-EOS

\\begin{description}
\\item[foo\\lbrack{}bar\\rbrack{}] \\mbox{} \\\\
foo. bar.
\\end{description}
EOS
    assert_equal expected, actual
  end

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    expected = <<-EOS

\\begin{description}
\\item[foo] \\mbox{} \\\\
foo.
\\end{description}

para

\\begin{description}
\\item[foo] \\mbox{} \\\\
foo.
\\end{description}

\\begin{enumerate}
\\item bar
\\end{enumerate}

\\begin{description}
\\item[foo] \\mbox{} \\\\
foo.
\\end{description}

\\begin{itemize}
\\item bar
\\end{itemize}
EOS
    assert_equal expected, actual
  end

  def test_dt_inline
    actual = compile_block("//footnote[bar][bar]\n\n : foo@<fn>{bar}[]<>&@<m>$\\alpha[]$\n")

    expected = <<-EOS

\\begin{description}
\\item[foo\\protect\\footnotemark{}\\lbrack{}\\rbrack{}\\textless{}\\textgreater{}\\&$\\alpha\\lbrack{}\\rbrack{}$] \\mbox{} \\\\

\\end{description}
EOS
    assert_equal expected, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewcmd}
foo
bar

buz
\\end{reviewcmd}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_cmd_caption
    actual = compile_block("//cmd[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\reviewcmdcaption{cap1}
\\begin{reviewcmd}
foo
bar

buz
\\end{reviewcmd}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//cmd[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewcmd}
foo
bar

buz
\\end{reviewcmd}
\\reviewcmdcaption{cap1}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_cmd_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//cmd{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewcmdlst}[language={}]
foo
bar

buz
\\end{reviewcmdlst}
EOS
    assert_equal expected, actual
  end

  def test_emlist
    actual = compile_block("//emlist{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewemlist}
foo
bar

buz
\\end{reviewemlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_emlist_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//emlist[][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    expected = <<-EOS

\\begin{reviewemlistlst}[language={sql}]
SELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'
\\end{reviewemlistlst}
EOS
    assert_equal expected, actual
  end

  def test_emlist_lst_without_lang
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    @book.config['highlight']['lang'] = 'sql'
    actual = compile_block("//emlist[]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    expected = <<-EOS

\\begin{reviewemlistlst}[language={sql}]
SELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'
\\end{reviewemlistlst}
EOS
    assert_equal expected, actual
  end

  def test_emlist_caption
    actual = compile_block("//emlist[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\reviewemlistcaption{cap1}
\\begin{reviewemlist}
foo
bar

buz
\\end{reviewemlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlist[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewemlist}
foo
bar

buz
\\end{reviewemlist}
\\reviewemlistcaption{cap1}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_emlist_empty_caption
    actual = compile_block("//emlist[]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewemlist}
foo
bar

buz
\\end{reviewemlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist{\n\tfoo\n\t\tbar\n\n\tbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewemlist}
        foo
                bar

        buz
\\end{reviewemlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_tab4
    @config['tabwidth'] = 4
    actual = compile_block("//emlist{\n\tfoo\n\t\tbar\n\n\tbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewemlist}
    foo
        bar

    buz
\\end{reviewemlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_emlistnum_caption
    actual = compile_block("//emlistnum[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\reviewemlistcaption{cap1}
\\begin{reviewemlist}
 1: foo
 2: bar
 3: 
 4: buz
\\end{reviewemlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlistnum[cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{reviewlistblock}
\\begin{reviewemlist}
 1: foo
 2: bar
 3: 
 4: buz
\\end{reviewemlist}
\\reviewemlistcaption{cap1}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_list
    actual = compile_block("//list[id1][cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\reviewlistcaption{リスト1.1: cap1}
\\begin{reviewlist}
foo
bar

buz
\\end{reviewlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//list[id1][cap1]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\begin{reviewlist}
foo
bar

buz
\\end{reviewlist}
\\reviewlistcaption{リスト1.1: cap1}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_list_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//list[id1][cap1][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    expected = <<-EOS
\\begin{reviewlistlst}[caption={cap1},language={sql}]
SELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'
\\end{reviewlistlst}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    # XXX: caption_position won't work with highlight
    actual = compile_block("//list[id1][cap1][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    expected = <<-EOS
\\begin{reviewlistlst}[caption={cap1},language={sql}]
SELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'
\\end{reviewlistlst}
EOS
    assert_equal expected, actual
  end

  def test_list_lst_with_lang
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    @book.config['highlight']['lang'] = 'sql'
    actual = compile_block("//list[id1][cap1]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    expected = <<-EOS
\\begin{reviewlistlst}[caption={cap1},language={sql}]
SELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'
\\end{reviewlistlst}
EOS
    assert_equal expected, actual
  end

  def test_listnum
    actual = compile_block("//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\reviewlistcaption{リスト1.1: ruby}
\\begin{reviewlist}
 1: class Foo
 2:   def foo
 3:     bar
 4: 
 5:     buz
 6:   end
 7: end
\\end{reviewlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\begin{reviewlist}
 1: class Foo
 2:   def foo
 3:     bar
 4: 
 5:     buz
 6:   end
 7: end
\\end{reviewlist}
\\reviewlistcaption{リスト1.1: ruby}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_listnum_linenum
    actual = compile_block("//firstlinenum[100]\n//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\reviewlistcaption{リスト1.1: ruby}
\\begin{reviewlist}
100: class Foo
101:   def foo
102:     bar
103: 
104:     buz
105:   end
106: end
\\end{reviewlist}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_listnum_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    expected = <<-EOS
\\begin{reviewlistnumlst}[caption={ruby},language={}]
class Foo
  def foo
    bar

    buz
  end
end
\\end{reviewlistnumlst}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    # XXX: caption_position won't work with highlight
    actual = compile_block("//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    expected = <<-EOS
\\begin{reviewlistnumlst}[caption={ruby},language={}]
class Foo
  def foo
    bar

    buz
  end
end
\\end{reviewlistnumlst}
EOS
    assert_equal expected, actual
  end

  def test_listnum_lst_linenum
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//firstlinenum[100]\n//listnum[test1][ruby]{\nclass Foo\n  def foo\n    bar\n\n    buz\n  end\nend\n//}\n")
    expected = <<-EOS
\\begin{reviewlistnumlst}[caption={ruby},language={},firstnumber=100]
class Foo
  def foo
    bar

    buz
  end
end
\\end{reviewlistnumlst}
EOS
    assert_equal expected, actual
  end

  def test_source
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\reviewsourcecaption{foo/bar/test.rb}
\\begin{reviewsource}
foo
bar

buz
\\end{reviewsource}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\begin{reviewsource}
foo
bar

buz
\\end{reviewsource}
\\reviewsourcecaption{foo/bar/test.rb}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_source_empty_caption
    actual = compile_block("//source[]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewlistblock}
\\begin{reviewsource}
foo
bar

buz
\\end{reviewsource}
\\end{reviewlistblock}
EOS
    assert_equal expected, actual
  end

  def test_source_lst
    @book.config['highlight'] = {}
    @book.config['highlight']['latex'] = 'listings'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewsourcelst}[title={foo/bar/test.rb},language={}]
foo
bar

buz
\\end{reviewsourcelst}
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    # XXX: caption_position won't work with highlight
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
\\begin{reviewsourcelst}[title={foo/bar/test.rb},language={}]
foo
bar

buz
\\end{reviewsourcelst}
EOS
    assert_equal expected, actual
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{quote}
foobar

buz
\\end{quote}
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{quote}
foo bar

buz
\\end{quote}
EOS
    assert_equal expected, actual
  end

  def test_memo
    actual = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS
\\begin{reviewmemo}[this is \\reviewbold{test}\\textless{}\\&\\textgreater{}\\textunderscore{}]

test1

test\\reviewit{2}

\\end{reviewmemo}
EOS
    assert_equal expected, actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{flushright}
foobar

buz
\\end{flushright}
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{flushright}
foo bar

buz
\\end{flushright}
EOS
    assert_equal expected, actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{center}
foobar

buz
\\end{center}
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

\\begin{center}
foo bar

buz
\\end{center}
EOS
    assert_equal expected, actual
  end

  def test_blankline
    actual = compile_block("//blankline\nfoo\n")
    expected = <<-EOS
\\par\\vspace{\\baselineskip}\\par

foo
EOS
    assert_equal expected, actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
\\noindent
foo
bar

foo2
bar2
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
\\noindent
foo bar

foo2 bar2
EOS
    assert_equal expected, actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[ ]{./images/chap1-sampleimg.png}
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    actual = compile_block("//image[sampleimg][sample photo][]{\n//}\n")
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = nil
    @config['caption_position']['image'] = 'top'
    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    actual = compile_block("//image[sampleimg][]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewimagecaption{}
\\label{image:chap1:sampleimg}
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    actual = compile_block("//image[sampleimg][][]{\n//}\n")
    assert_equal expected, actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[scale=1.2]{./images/chap1-sampleimg.png}
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal expected, actual
  end

  def test_image_with_metric_width
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    @config['pdfmaker']['image_scale2width'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=1.2\\maxwidth]{./images/chap1-sampleimg.png}
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal expected, actual
  end

  def test_image_with_metric2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[scale=1.2,ignore=params]{./images/chap1-sampleimg.png}
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal expected, actual
  end

  def test_image_with_metric2_width
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    @config['pdfmaker']['image_scale2width'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=1.2\\maxwidth,ignore=params]{./images/chap1-sampleimg.png}
\\reviewimagecaption{sample photo}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal expected, actual
  end

  def test_indepimage
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\reviewindepimagecaption{図: sample photo}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[ ]{./images/chap1-sampleimg.png}
\\reviewindepimagecaption{図: sample photo}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    actual = compile_block("//indepimage[sampleimg][sample photo][]\n")
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = nil
    @config['caption_position']['image'] = 'top'
    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewindepimagecaption{図: sample photo}
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
EOS
    assert_equal expected, actual
  end

  def test_indepimage_without_caption
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    actual = compile_block("//indepimage[sampleimg]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    actual = compile_block("//indepimage[sampleimg][]\n")
    assert_equal expected, actual

    actual = compile_block("//indepimage[sampleimg][][]\n")
    assert_equal expected, actual
  end

  def test_indepimage_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[scale=1.2]{./images/chap1-sampleimg.png}
\\reviewindepimagecaption{図: sample photo}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal expected, actual
  end

  def test_indepimage_with_metric_width
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    @config['pdfmaker']['image_scale2width'] = true
    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=1.2\\maxwidth]{./images/chap1-sampleimg.png}
\\reviewindepimagecaption{図: sample photo}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal expected, actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block(%Q(//indepimage[sampleimg][sample photo][scale=1.2, html::class="sample",latex::ignore=params]\n))
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[scale=1.2,ignore=params]{./images/chap1-sampleimg.png}
\\reviewindepimagecaption{図: sample photo}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block(%Q(//indepimage[sampleimg][sample photo][scale=1.2, html::class="sample",latex::ignore=params]\n))
    assert_equal expected, actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    # FIXME: indepimage's caption should not be with a counter.
    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    expected = <<-EOS
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[scale=1.2]{./images/chap1-sampleimg.png}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal expected, actual
  end

  def test_indepimage_nofile
    def @chapter.image(_id)
      item = Book::Index::Item.new('sample_img_nofile_', 1)
      item.instance_eval do
        def path
          nil
        end
      end
      item
    end

    io = StringIO.new
    @builder.instance_eval { @logger = ReVIEW::Logger.new(io) }

    actual = compile_block("//indepimage[sample_img_nofile_][sample photo]\n")
    expected = <<-EOS
\\begin{reviewdummyimage}
{-}{-}[[path = sample\\reviewbackslash{}textunderscore\\{\\}img\\reviewbackslash{}textunderscore\\{\\}nofile\\reviewbackslash{}textunderscore\\{\\} (not exist)]]{-}{-}
\\reviewindepimagecaption{図: sample photo}
\\end{reviewdummyimage}
EOS
    assert_equal expected, actual
    assert_match(/WARN --: :1: image not bound: sample_img_nofile_/, io.string)
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
\\begin{table}%%foo
\\reviewtablecaption{FOO}
\\label{table:chap1:foo}
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
\\end{table}
EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
\\begin{table}%%foo
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
\\reviewtablecaption{FOO}
\\label{table:chap1:foo}
\\end{table}
EOS
    assert_equal expected, actual
  end

  def test_empty_table
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//table{\n//}\n") }
    assert_equal 'no rows in the table', e.message

    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//table{\n------------\n//}\n") }
    assert_equal 'no rows in the table', e.message
  end

  def test_customize_cellwidth
    actual = compile_block("//tsize[2,3,5]\n//table{\nA\tB\tC\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|p{2mm}|p{3mm}|p{5mm}|}
\\hline
\\reviewth{A} & B & C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    actual = compile_block("//tsize[|latex,html|2,3,5]\n//table{\nA\tB\tC\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|p{2mm}|p{3mm}|p{5mm}|}
\\hline
\\reviewth{A} & B & C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    actual = compile_block("//tsize[|html|2,3,5]\n//table{\nA\tB\tC\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|l|l|l|}
\\hline
\\reviewth{A} & B & C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    actual = compile_block("//tsize[|latex|2,3,5]\n//table{\nA\tB\tC\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|p{2mm}|p{3mm}|p{5mm}|}
\\hline
\\reviewth{A} & B & C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    actual = compile_block("//tsize[|latex||p{5mm}|cr|]\n//table{\nA\tB\tC\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|p{5mm}|cr|}
\\hline
\\reviewth{A} & B & C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual
  end

  def test_separate_tsize
    actual = @builder.separate_tsize('|l|c|r|p{1cm}lp{1.5cm}|p{5mm}').join(',')
    assert_equal 'l,c,r,p{1cm},l,p{1.5cm},p{5mm}', actual

    actual = @builder.separate_tsize('|lcr').join(',')
    assert_equal 'l,c,r', actual

    actual = @builder.separate_tsize('{p}p{').join(',')
    assert_equal '{p},p{', actual
  end

  def test_break_tablecell
    actual = compile_block("//tsize[|latex||p{10mm}|cp{10mm}|]\n//table{\nA@<br>{}A\tB@<br>{}B\tC@<br>{}C\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|p{10mm}|cp{10mm}|}
\\hline
\\reviewth{A\\newline{}A} & \\shortstack[l]{B\\\\
B} & C\\newline{}C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    actual = compile_block("//tsize[|latex||p{10mm}|cp{10mm}|]\n//table{\n1@<br>{}1\t2@<br>{}2\t3\n------------\nA@<br>{}A\tB@<br>{}B\tC@<br>{}C\n//}\n")
    expected = <<-EOS
\\begin{reviewtable}{|p{10mm}|cp{10mm}|}
\\hline
\\reviewth{1\\newline{}1} & \\reviewth{\\shortstack[l]{2\\\\
2}} & \\reviewth{3} \\\\  \\hline
A\\newline{}A & \\shortstack[l]{B\\\\
B} & C\\newline{}C \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
\\begin{table}%%
\\reviewtablecaption*{foo}
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
\\end{table}

\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
\\begin{table}%%
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
\\reviewtablecaption*{foo}
\\end{table}

\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{aaa} & \\reviewth{bbb} \\\\  \\hline
ccc & ddd\\textless{}\\textgreater{}\\& \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual
  end

  def test_imgtable
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1, 'sample img')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")

    expected = <<-EOS
\\begin{table}[h]%%sampleimg
\\reviewimgtablecaption{test for imgtable}
\\label{table:chap1:sampleimg}
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
\\end{table}
EOS
    assert_equal expected, actual

    actual = compile_block("//imgtable[sampleimg][]{\n//}\n")
    expected = <<-EOS
\\label{table:chap1:sampleimg}
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
EOS
    assert_equal expected, actual

    actual = compile_block("//imgtable[sampleimg][][]{\n//}\n")
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")

    expected = <<-EOS
\\begin{table}[h]%%sampleimg
\\reviewimgtablecaption{test for imgtable}
\\label{table:chap1:sampleimg}
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[ ]{./images/chap1-sampleimg.png}
\\end{reviewimage}
\\end{table}
EOS
    assert_equal expected, actual

    actual = compile_block("//imgtable[sampleimg][test for imgtable][]{\n//}\n")
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = nil
    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")

    expected = <<-EOS
\\begin{table}[h]%%sampleimg
\\label{table:chap1:sampleimg}
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\end{reviewimage}
\\reviewimgtablecaption{test for imgtable}
\\end{table}
EOS
    assert_equal expected, actual
  end

  def test_imgtable_with_metrics
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1, 'sample img')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//imgtable[sampleimg][test for imgtable][scale=1.2]{\n//}\n")
    expected = <<-EOS
\\begin{table}[h]%%sampleimg
\\reviewimgtablecaption{test for imgtable}
\\label{table:chap1:sampleimg}
\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[scale=1.2]{./images/chap1-sampleimg.png}
\\end{reviewimage}
\\end{table}
EOS
    assert_equal expected, actual

    @book.config['pdfmaker']['use_original_image_size'] = true
    actual = compile_block("//imgtable[sampleimg][test for imgtable][scale=1.2]{\n//}\n")
    assert_equal expected, actual
  end

  def test_table_row_separator
    src = "//table{\n1\t2\t\t3  4| 5\n------------\na b\tc  d   |e\n//}\n"
    expected = <<-EOS
\\begin{reviewtable}{|l|l|l|}
\\hline
\\reviewth{1} & \\reviewth{2} & \\reviewth{3  4\\textbar{} 5} \\\\  \\hline
a b & c  d   \\textbar{}e &  \\\\  \\hline
\\end{reviewtable}
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['table_row_separator'] = 'singletab'
    actual = compile_block(src)
    expected = <<-EOS
\\begin{reviewtable}{|l|l|l|l|}
\\hline
\\reviewth{1} & \\reviewth{2} & \\reviewth{} & \\reviewth{3  4\\textbar{} 5} \\\\  \\hline
a b & c  d   \\textbar{}e &  &  \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'spaces'
    actual = compile_block(src)
    expected = <<-EOS
\\begin{reviewtable}{|l|l|l|l|l|}
\\hline
\\reviewth{1} & \\reviewth{2} & \\reviewth{3} & \\reviewth{4\\textbar{}} & \\reviewth{5} \\\\  \\hline
a & b & c & d & \\textbar{}e \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'verticalbar'
    actual = compile_block(src)
    expected = <<-EOS
\\begin{reviewtable}{|l|l|}
\\hline
\\reviewth{1	2		3  4} & \\reviewth{5} \\\\  \\hline
a b	c  d & e \\\\  \\hline
\\end{reviewtable}
EOS
    assert_equal expected, actual
  end

  def test_bib
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    assert_equal '\\reviewbibref{[1]}{bib:samplebib}', compile_inline('@<bib>{samplebib}')
  end

  def test_bibpaper
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    expected = <<-EOS
[1] sample bib \\reviewbold{bold}
\\label{bib:samplebib}

ab

EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    expected = <<-EOS
[1] sample bib \\reviewbold{bold}
\\label{bib:samplebib}

a b

EOS
    assert_equal expected, actual
  end

  def test_bibpaper_without_body
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[samplebib][sample bib]\n")
    expected = <<-EOS
[1] sample bib
\\label{bib:samplebib}

EOS
    assert_equal expected, actual
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

\\begin{reviewcolumn}[prev column\\hypertarget{column:chap1:1}{}]
\\addcontentsline{toc}{subsection}{prev column}

inside prev column

\\end{reviewcolumn}

\\begin{reviewcolumn}[test\\hypertarget{column:chap1:2}{}]
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

\\begin{reviewcolumn}[test\\hypertarget{column:chap1:1}{}]

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
\\item AAA
{-}AA
\\item BBB
{-}BB
\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    expected = <<-EOS

\\begin{itemize}
\\item AAA {-}AA
\\item BBB {-}BB
\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_cont_with_br
    src = <<-EOS
  * AAA@<br>{}
    -AA
  * BBB@<br>{}1@<br>{}
    -BB
EOS
    expected = <<-EOS

\\begin{itemize}
\\item AAA\\\\
{-}AA
\\item BBB\\\\
1\\\\
{-}BB
\\end{itemize}
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    expected = <<-EOS

\\begin{itemize}
\\item AAA\\\\
 {-}AA
\\item BBB\\\\
1\\\\
 {-}BB
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
    expected = <<-EOS
\\begin{reviewnote}

A

B

\\end{reviewnote}
\\begin{reviewnote}[caption]

A

\\end{reviewnote}
EOS
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewmemo}

A

B

\\end{reviewmemo}
\\begin{reviewmemo}[caption]

A

\\end{reviewmemo}
EOS
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewinfo}

A

B

\\end{reviewinfo}
\\begin{reviewinfo}[caption]

A

\\end{reviewinfo}
EOS
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewimportant}

A

B

\\end{reviewimportant}
\\begin{reviewimportant}[caption]

A

\\end{reviewimportant}
EOS
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewcaution}

A

B

\\end{reviewcaution}
\\begin{reviewcaution}[caption]

A

\\end{reviewcaution}
EOS
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewnotice}

A

B

\\end{reviewnotice}
\\begin{reviewnotice}[caption]

A

\\end{reviewnotice}
EOS
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewwarning}

A

B

\\end{reviewwarning}
\\begin{reviewwarning}[caption]

A

\\end{reviewwarning}
EOS
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = <<-EOS
\\begin{reviewtip}

A

B

\\end{reviewtip}
\\begin{reviewtip}[caption]

A

\\end{reviewtip}
EOS
    assert_equal expected, actual
  end

  def test_minicolumn_blocks
    %w[note memo tip info warning important caution notice].each do |type|
      src = <<-EOS
//#{type}[#{type}1]{

//}

//#{type}[#{type}2]{
//}
EOS

      expected = <<-EOS
\\begin{review#{type}}[#{type}1]
\\end{review#{type}}
\\begin{review#{type}}[#{type}2]
\\end{review#{type}}
EOS
      assert_equal expected, compile_block(src)

      src = <<-EOS
//#{type}[#{type}2]{

//}

//#{type}[#{type}3]{

//}

//#{type}[#{type}4]{

//}

//#{type}[#{type}5]{

//}

//#{type}[#{type}6]{

//}
EOS

      expected = <<-EOS
\\begin{review#{type}}[#{type}2]
\\end{review#{type}}
\\begin{review#{type}}[#{type}3]
\\end{review#{type}}
\\begin{review#{type}}[#{type}4]
\\end{review#{type}}
\\begin{review#{type}}[#{type}5]
\\end{review#{type}}
\\begin{review#{type}}[#{type}6]
\\end{review#{type}}
EOS
      assert_equal expected, compile_block(src)

      src = <<-EOS
//#{type}{

 * A

 1. B

//}

//#{type}[OMITEND1]{

//emlist{
LIST
//}

//}
//#{type}[OMITEND2]{
//}
EOS

      expected = <<-EOS
\\begin{review#{type}}

\\begin{itemize}
\\item A
\\end{itemize}

\\begin{enumerate}
\\item B
\\end{enumerate}

\\end{review#{type}}
\\begin{review#{type}}[OMITEND1]

\\begin{reviewlistblock}
\\begin{reviewemlist}
LIST
\\end{reviewemlist}
\\end{reviewlistblock}

\\end{review#{type}}
\\begin{review#{type}}[OMITEND2]
\\end{review#{type}}
EOS
      assert_equal expected, compile_block(src)
    end
  end

  def test_minicolumn_blocks_nest_error1
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//#{type}{
//}

//}
EOS
      assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, @log_io.string)
    end
  end

  def test_minicolumn_blocks_nest_error2
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//#{type}{

//}

//}
EOS
      assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, @log_io.string)
    end
  end

  def test_minicolumn_blocks_nest_error3
    %w[memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//note{
//}

//}
EOS
      assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, @log_io.string)
    end
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
      item = Book::Index::Item.new('sampleimg', 1, 'sample photo')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = "\n\\reviewimageref{1.1}{image:chap1:sampleimg}「sample photo」\n"
    assert_equal expected, actual
  end

  def test_inline_imgref2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<imgref>{sampleimg}\n")
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
    actual = compile_block('//comment[コメント<]')
    assert_equal %Q(\\pdfcomment{コメント\\textless{}}\n), actual
    actual = compile_block("//comment{\nA<>\nB&\n//}")
    assert_equal %Q(\\pdfcomment{A\\textless{}\\textgreater{}\\par B\\&}\n), actual
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
    assert_equal 'test \\reviewcode{@\\textless{}code\\textgreater{}\\{\\textdollar{}サンプル\\textdollar{}\\}}', actual
    actual2 = compile_inline('test @<code>|@<code>{$サンプル$}|, @<m>$\begin{array}{ll}a & b\\\alpha & @\\\end{array}$')
    assert_equal 'test \\reviewcode{@\\textless{}code\\textgreater{}\\{\\textdollar{}サンプル\\textdollar{}\\}}, $\begin{array}{ll}a & b\\\alpha & @\\\end{array}$', actual2
  end

  def test_inline_w
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'words.csv'), <<EOB
"F","foo"
"B","bar""\\<>_@<b>{BAZ}"
EOB
      )
      @book.config['words_file'] = File.join(dir, 'words.csv')

      io = StringIO.new
      @builder.instance_eval { @logger = ReVIEW::Logger.new(io) }
      actual = compile_block('@<w>{F} @<w>{B} @<wb>{B} @<w>{N}')
      expected = <<-EOS

foo bar"\\reviewbackslash{}\\textless{}\\textgreater{}\\textunderscore{}@\\textless{}b\\textgreater{}\\{BAZ\\} \\reviewbold{bar"\\reviewbackslash{}\\textless{}\\textgreater{}\\textunderscore{}@\\textless{}b\\textgreater{}\\{BAZ\\}} [missing word: N]
EOS
      assert_equal expected, actual
      assert_match(/WARN --: :1: word not bound: N/, io.string)
    end
  end

  def test_inline_unknown
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<img>{n}\n") }
    assert_match(/unknown image: n/, @log_io.string)

    @log_io.rewind
    @log_io.truncate(0)
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<fn>{n}\n") }
    assert_match(/unknown footnote: n/, @log_io.string)

    @log_io.rewind
    @log_io.truncate(0)
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<hd>{n}\n") }
    assert_match(/unknown headline: n/, @log_io.string)
    %w[list table column].each do |name|
      @log_io.rewind
      @log_io.truncate(0)
      assert_raises(ReVIEW::ApplicationError) { compile_block("@<#{name}>{n}\n") }
      assert_match(/unknown #{name}: n/, @log_io.string)
    end
    %w[chap chapref title].each do |name|
      @log_io.rewind
      @log_io.truncate(0)
      assert_raises(ReVIEW::ApplicationError) { compile_block("@<#{name}>{n}\n") }
      assert_match(/key not found: "n"/, @log_io.string)
    end
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

\\begin{reviewlistblock}
\\reviewlistcaption{リストA.1: FOO}
\\begin{reviewlist}
\\end{reviewlist}
\\end{reviewlistblock}
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

\\begin{table}%%foo
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
      item = Book::Index::Item.new('sampleimg', 1)
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

\\begin{reviewimage}%%sampleimg
\\reviewincludegraphics[width=\\maxwidth]{./images/chap1-sampleimg.png}
\\reviewimagecaption{FOO}
\\label{image:chap1:sampleimg}
\\end{reviewimage}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_texequation
    src = <<-EOS
//texequation{
e=mc^2
//}
EOS
    expected = <<-EOS

\\begin{equation*}
e=mc^2
\\end{equation*}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_texequation_with_caption
    src = <<-EOS
@<eq>{emc2}

//texequation[emc2][The Equivalence of Mass @<i>{and} Energy]{
e=mc^2
//}
EOS
    expected = <<-EOS

\\reviewequationref{1.1}

\\begin{reviewequationblock}
\\reviewequationcaption{式1.1: The Equivalence of Mass \\reviewit{and} Energy}
\\begin{equation*}
e=mc^2
\\end{equation*}
\\end{reviewequationblock}
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['caption_position']['equation'] = 'bottom'
    expected = <<-EOS

\\reviewequationref{1.1}

\\begin{reviewequationblock}
\\begin{equation*}
e=mc^2
\\end{equation*}
\\reviewequationcaption{式1.1: The Equivalence of Mass \\reviewit{and} Energy}
\\end{reviewequationblock}
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_error_close1
    src = <<-EOS
//beginchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ":1: //beginchild is shown, but previous element isn't ul, ol, or dl", e.message
  end

  def test_nest_error_close2
    src = <<-EOS
 * foo

//beginchild

 1. foo

//beginchild

 : foo

//beginchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ':12: //beginchild of dl,ol,ul misses //endchild', e.message
  end

  def test_nest_error_close3
    src = <<-EOS
 * foo

//beginchild

 1. foo

//beginchild

 : foo

//beginchild

//endchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ':14: //beginchild of ol,ul misses //endchild', e.message
  end

  def test_nest_ul
    src = <<-EOS
 * UL1

//beginchild

 1. UL1-OL1
 2. UL1-OL2

 * UL1-UL1
 * UL1-UL2

 : UL1-DL1
	UL1-DD1
 : UL1-DL2
	UL1-DD2

//endchild

 * UL2

//beginchild

UL2-PARA

//endchild
EOS

    expected = <<-EOS

\\begin{itemize}
\\item UL1


\\begin{enumerate}
\\item UL1{-}OL1
\\item UL1{-}OL2
\\end{enumerate}

\\begin{itemize}
\\item UL1{-}UL1
\\item UL1{-}UL2
\\end{itemize}

\\begin{description}
\\item[UL1{-}DL1] \\mbox{} \\\\
UL1{-}DD1
\\item[UL1{-}DL2] \\mbox{} \\\\
UL1{-}DD2
\\end{description}


\\item UL2


UL2{-}PARA

\\end{itemize}
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_ol
    src = <<-EOS
 1. OL1

//beginchild

 1. OL1-OL1
 2. OL1-OL2

 * OL1-UL1
 * OL1-UL2

 : OL1-DL1
	OL1-DD1
 : OL1-DL2
	OL1-DD2

//endchild

 2. OL2

//beginchild

OL2-PARA

//endchild
EOS

    expected = <<-EOS

\\begin{enumerate}
\\item OL1


\\begin{enumerate}
\\item OL1{-}OL1
\\item OL1{-}OL2
\\end{enumerate}

\\begin{itemize}
\\item OL1{-}UL1
\\item OL1{-}UL2
\\end{itemize}

\\begin{description}
\\item[OL1{-}DL1] \\mbox{} \\\\
OL1{-}DD1
\\item[OL1{-}DL2] \\mbox{} \\\\
OL1{-}DD2
\\end{description}


\\item OL2


OL2{-}PARA

\\end{enumerate}
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_dl
    src = <<-EOS
 : DL1

//beginchild

 1. DL1-OL1
 2. DL1-OL2

 * DL1-UL1
 * DL1-UL2

 : DL1-DL1
	DL1-DD1
 : DL1-DL2
	DL1-DD2

//endchild

 : DL2
	DD2

//beginchild

 * DD2-UL1
 * DD2-UL2

DD2-PARA

//endchild
EOS

    expected = <<-EOS

\\begin{description}
\\item[DL1] \\mbox{} \\\\



\\begin{enumerate}
\\item DL1{-}OL1
\\item DL1{-}OL2
\\end{enumerate}

\\begin{itemize}
\\item DL1{-}UL1
\\item DL1{-}UL2
\\end{itemize}

\\begin{description}
\\item[DL1{-}DL1] \\mbox{} \\\\
DL1{-}DD1
\\item[DL1{-}DL2] \\mbox{} \\\\
DL1{-}DD2
\\end{description}


\\item[DL2] \\mbox{} \\\\
DD2


\\begin{itemize}
\\item DD2{-}UL1
\\item DD2{-}UL2
\\end{itemize}

DD2{-}PARA

\\end{description}
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_multi
    src = <<-EOS
 1. OL1

//beginchild

 1. OL1-OL1

//beginchild

 * OL1-OL1-UL1

OL1-OL1-PARA

//endchild

 2. OL1-OL2

 * OL1-UL1

//beginchild

 : OL1-UL1-DL1
	OL1-UL1-DD1

OL1-UL1-PARA

//endchild

 * OL1-UL2

//endchild
EOS
    expected = <<-EOS

\\begin{enumerate}
\\item OL1


\\begin{enumerate}
\\item OL1{-}OL1


\\begin{itemize}
\\item OL1{-}OL1{-}UL1
\\end{itemize}

OL1{-}OL1{-}PARA


\\item OL1{-}OL2
\\end{enumerate}

\\begin{itemize}
\\item OL1{-}UL1


\\begin{description}
\\item[OL1{-}UL1{-}DL1] \\mbox{} \\\\
OL1{-}UL1{-}DD1
\\end{description}

OL1{-}UL1{-}PARA


\\item OL1{-}UL2
\\end{itemize}

\\end{enumerate}
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_graph_mermaid
    def @chapter.image(_id)
      item = Book::Index::Item.new('id', 1, 'id')
      item.instance_eval { @path = './images/latex/id.pdf' }
      item
    end

    begin
      require 'playwrightrunner'
    rescue LoadError
      return true
    end

    actual = compile_block("//graph[id][mermaid][foo]{\ngraph LR; B --> C\n//}")
    expected = <<-EOS
\\begin{reviewimage}%%id
\\reviewincludegraphics[width=\\maxwidth]{./images/latex/id.pdf}
\\reviewimagecaption{foo}
\\label{image:chap1:id}
\\end{reviewimage}
EOS
    assert_equal expected, actual
  end
end
