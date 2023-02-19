require 'test_helper'
require 'book_test_helper'
require 'review/compiler'
require 'review/book'
require 'review/idgxmlbuilder'
require 'review/i18n'

class IDGXMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def setup
    @builder = IDGXMLBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['tableopt'] = '10'
    @book = Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup('ja')
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(<title id="test" aid:pstyle="h1">第1章　this is test.</title><?dtp level="1" section="第1章　this is test."?>), actual
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(<title id="test" aid:pstyle="h1">this is test.</title><?dtp level="1" section="this is test."?>), actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q(<title id="test" aid:pstyle="h2">1.1　this is test.</title><?dtp level="2" section="1.1　this is test."?>), actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(<title id="test" aid:pstyle="h3">this is test.</title><?dtp level="3" section="this is test."?>), actual
  end

  def test_headline_level3_with_secno
    @config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(<title id="test" aid:pstyle="h3">1.0.1　this is test.</title><?dtp level="3" section="1.0.1　this is test."?>), actual
  end

  def test_headline_secttags
    @config['structuredxml'] = true
    actual = compile_block("= HEAD1\n== HEAD1-1\n\n=== HEAD1-1-1\n\n== HEAD1-2\n\n==== HEAD1-2-0-1\n\n===== HEAD1-2-0-1-1\n\n== HEAD1-3\n")
    expected = '<chapter id="chap:1"><title aid:pstyle="h1">第1章　HEAD1</title><?dtp level="1" section="第1章　HEAD1"?>' +
               '<sect id="sect:1.1"><title aid:pstyle="h2">1.1　HEAD1-1</title><?dtp level="2" section="1.1　HEAD1-1"?>' +
               '<sect2 id="sect:1.1.1"><title aid:pstyle="h3">HEAD1-1-1</title><?dtp level="3" section="HEAD1-1-1"?></sect2></sect>' +
               '<sect id="sect:1.2"><title aid:pstyle="h2">1.2　HEAD1-2</title><?dtp level="2" section="1.2　HEAD1-2"?>' +
               '<sect3 id="sect:1.2.0.1"><title aid:pstyle="h4">HEAD1-2-0-1</title><?dtp level="4" section="HEAD1-2-0-1"?>' +
               '<sect4 id="sect:1.2.0.1.1"><title aid:pstyle="h5">HEAD1-2-0-1-1</title><?dtp level="5" section="HEAD1-2-0-1-1"?></sect4></sect3></sect>' +
               '<sect id="sect:1.3"><title aid:pstyle="h2">1.3　HEAD1-3</title><?dtp level="2" section="1.3　HEAD1-3"?></sect></chapter>'
    assert_equal expected, actual
  end

  def test_label
    actual = compile_block("//label[label_test]\n")
    assert_equal %Q(<label id='label_test' />), actual
  end

  def test_inline_ref
    actual = compile_inline('@<ref>{外部参照<>&}')
    assert_equal %Q(<ref idref='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</ref>), actual
  end

  def test_href
    actual = compile_inline('@<href>{http://github.com,GitHub}')
    assert_equal %Q(<a linkurl='http://github.com'>GitHub</a>), actual
  end

  def test_href_without_label
    actual = compile_inline('@<href>{http://github.com}')
    assert_equal %Q(<a linkurl='http://github.com'>http://github.com</a>), actual
  end

  def test_inline_href
    actual = compile_inline('@<href>{http://github.com, Git\\,Hub}')
    assert_equal %Q(<a linkurl='http://github.com'>Git,Hub</a>), actual
  end

  def test_inline_raw
    actual = compile_inline('@<raw>{@<tt>{inline\\}}')
    assert_equal %Q(@<tt>{inline}), actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><b>1</b></td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><i>2</i></td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><b>3</b></td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><i>4</i>&lt;&gt;&amp;</td></tbody></table>), actual
  end

  def test_inline_in_table_without_header
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><b>1</b></td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><i>2</i></td><td xyh="1,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><b>3</b></td><td xyh="2,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172"><i>4</i>&lt;&gt;&amp;</td></tbody></table>), actual
  end

  def test_inline_in_table_without_cellwidth
    @config['tableopt'] = nil
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q(<table><tbody><tr type="header"><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>), actual
  end

  def test_inline_in_table_without_header_and_cellwidth
    @config['tableopt'] = nil
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q(<table><tbody><tr><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>), actual
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS.chomp
<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">aaa</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">bbb</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">ccc</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">ddd&lt;&gt;&amp;</td></tbody></table>
EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS.chomp
<table><caption>表1.1　FOO</caption><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">aaa</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">bbb</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">ccc</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">ddd&lt;&gt;&amp;</td></tbody></table>
EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS.chomp
<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">aaa</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">bbb</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">ccc</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">ddd&lt;&gt;&amp;</td></tbody><caption>表1.1　FOO</caption></table>
EOS
    assert_equal expected, actual
  end

  def test_customize_cellwidth
    actual = compile_block("//tsize[2,3,5]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="3"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">A</td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="8.503">B</td><td xyh="3,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">C</td></tbody></table>), actual

    actual = compile_block("//tsize[2,3]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="3"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">A</td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="8.503">B</td><td xyh="3,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">C</td></tbody></table>), actual

    actual = compile_block("//tsize[2]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="3"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">A</td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="11.338">B</td><td xyh="3,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="11.338">C</td></tbody></table>), actual

    actual = compile_block("//tsize[|idgxml|2]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="3"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">A</td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="11.338">B</td><td xyh="3,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="11.338">C</td></tbody></table>), actual

    actual = compile_block("//tsize[|idgxml,html|2]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="3"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">A</td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="11.338">B</td><td xyh="3,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="11.338">C</td></tbody></table>), actual

    actual = compile_block("//tsize[|html|2]\n//table{\nA\tB\tC\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="3"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">A</td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">B</td><td xyh="3,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">C</td></tbody></table>), actual
  end

  def test_customize_mmtopt
    actual = compile_block("//table{\nA\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody></table>), actual

    @config['pt_to_mm_unit'] = 0.3514
    actual = compile_block("//table{\nA\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.458">A</td></tbody></table>), actual

    @config['pt_to_mm_unit'] = '0.3514'
    actual = compile_block("//table{\nA\n//}\n")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.458">A</td></tbody></table>), actual
  end

  def test_empty_table
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//table{\n//}\n") }
    assert_equal 'no rows in the table', e.message

    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//table{\n------------\n//}\n") }
    assert_equal 'no rows in the table', e.message
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\nA\n//}\n//emtable{\nA\n//}")
    assert_equal %Q(<table><caption>foo</caption><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody></table><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody></table>), actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//emtable[foo]{\nA\n//}\n//emtable{\nA\n//}")
    assert_equal %Q(<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody><caption>foo</caption></table><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody></table>), actual
  end

  def test_table_row_separator
    src = "//table{\n1\t2\t\t3  4| 5\n------------\na b\tc  d   |e\n//}\n"
    expected = <<-EOS.chomp
<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="3"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">1</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">2</td><td xyh="3,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">3  4| 5</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">a b</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="9.448">c  d   |e</td></tbody></table>
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['table_row_separator'] = 'singletab'
    actual = compile_block(src)
    expected = <<-EOS.chomp
<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="4"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="7.086">1</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="7.086">2</td><td xyh="3,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="7.086"></td><td xyh="4,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="7.086">3  4| 5</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="7.086">a b</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="7.086">c  d   |e</td></tbody></table>
EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'spaces'
    actual = compile_block(src)
    expected = <<-EOS.chomp
<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="5"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">1</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">2</td><td xyh="3,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">3</td><td xyh="4,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">4|</td><td xyh="5,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">5</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">a</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">b</td><td xyh="3,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">c</td><td xyh="4,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">d</td><td xyh="5,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="5.669">|e</td></tbody></table>
EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'verticalbar'
    actual = compile_block(src)
    expected = <<-EOS.chomp
<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">1	2		3  4</td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">5</td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">a b	c  d</td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.172">e</td></tbody></table>
EOS
    assert_equal expected, actual
  end

  def test_inline_br
    actual = compile_inline('@<br>{}')
    assert_equal "\n", actual
  end

  def test_inline_uchar
    actual = compile_inline('test @<uchar>{2460} test2')
    assert_equal 'test &#x2460; test2', actual
  end

  def test_inline_ruby
    actual = compile_inline('@<ruby>{coffin,bed}')
    assert_equal %Q(<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>coffin</aid:rb><aid:rt>bed</aid:rt></aid:ruby></GroupRuby>), actual

    actual = compile_inline('@<ruby>{     coffin  ,   bed   }')
    assert_equal %Q(<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>coffin</aid:rb><aid:rt>bed</aid:rt></aid:ruby></GroupRuby>), actual
  end

  def test_inline_kw
    actual = compile_inline('@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}')
    assert_equal %Q(<keyword>ISO（International Organization for Standardization）</keyword><index value="ISO" /><index value="International Organization for Standardization" /> <keyword>Ruby&lt;&gt;</keyword><index value="Ruby&lt;&gt;" />), actual
  end

  def test_inline_maru
    actual = compile_inline('@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}')
    assert_equal '&#x2460;&#x2473;&#x24b6;&#x24e9;', actual
  end

  def test_inline_ttb
    actual = compile_inline(%Q(@<ttb>{test * <>"}))
    assert_equal %Q(<tt style='bold'>test * &lt;&gt;&quot;</tt>), actual
  end

  def test_inline_ttbold
    actual = compile_inline(%Q(@<ttbold>{test * <>"}))
    assert_equal %Q(<tt style='bold'>test * &lt;&gt;&quot;</tt>), actual
  end

  def test_inline_balloon
    actual = compile_inline('@<balloon>{@maru[1]test}')
    assert_equal '<balloon>&#x2460;test</balloon>', actual
  end

  def test_inline_m
    actual = compile_inline('@<m>{\\sin} @<m>{\\frac{1\\}{2\\}}')
    assert_equal %Q(<replace idref="texinline-1"><pre>\\sin</pre></replace> <replace idref="texinline-2"><pre>\\frac{1}{2}</pre></replace>), actual
  end

  def test_inline_m_imgmath
    @config['math_format'] = 'imgmath'
    actual = compile_inline('@<m>{\\sin} @<m>{\\frac{1\\}{2\\}}')
    assert_equal %Q(<inlineequation><Image href="file://images/_review_math/_gen_5fded382aa33f0f0652092d41e05c743f7453c26ca1433038a4883234975a9b0.png" type="inline" /></inlineequation> <inlineequation><Image href="file://images/_review_math/_gen_e7e9536310cdba7ff948771f791cefe32f99b73c608778c9660db79e4926e9f9.png" type="inline" /></inlineequation>), actual
  end

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    assert_equal %Q(<dl><dt>foo</dt><dd>foo.</dd></dl><p>para</p><dl><dt>foo</dt><dd>foo.</dd></dl><ol><li aid:pstyle="ol-item" olnum="1" num="1">bar</li></ol><dl><dt>foo</dt><dd>foo.</dd></dl><ul><li aid:pstyle="ul-item">bar</li></ul>), actual
  end

  def test_dt_inline
    actual = compile_block("//footnote[bar][bar]\n\n : foo@<fn>{bar}[]<>&@<m>$\\alpha[]$\n")

    expected = <<-EOS.chomp
<dl><dt>foo<footnote>bar</footnote>[]&lt;&gt;&amp;<replace idref="texinline-1"><pre>\\alpha[]</pre></replace></dt><dd></dd></dl>
EOS
    assert_equal expected, actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal '<p>foobar</p>', actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("foo\nbar\n")
    assert_equal '<p>foo bar</p>', actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(<p inlist="1">foobar</p>), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(<p inlist="1">foo bar</p>), actual
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal '<quote><p>foobar</p><p>buz</p></quote>', actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal '<quote><p>foo bar</p><p>buz</p></quote>', actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = %Q(<note><p>A</p><p>B</p></note><note><title aid:pstyle='note-title'>caption</title><p>A</p></note>)
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = %Q(<memo><p>A</p><p>B</p></memo><memo><title aid:pstyle='memo-title'>caption</title><p>A</p></memo>)
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = %Q(<info><p>A</p><p>B</p></info><info><title aid:pstyle='info-title'>caption</title><p>A</p></info>)
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = %Q(<important><p>A</p><p>B</p></important><important><title aid:pstyle='important-title'>caption</title><p>A</p></important>)
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = %Q(<caution><p>A</p><p>B</p></caution><caution><title aid:pstyle='caution-title'>caption</title><p>A</p></caution>)
    assert_equal expected, actual

    # notice uses special tag notice-t if it includes caption
    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = %Q(<notice><p>A</p><p>B</p></notice><notice-t><title aid:pstyle='notice-title'>caption</title><p>A</p></notice-t>)
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = %Q(<warning><p>A</p><p>B</p></warning><warning><title aid:pstyle='warning-title'>caption</title><p>A</p></warning>)
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = %Q(<tip><p>A</p><p>B</p></tip><tip><title aid:pstyle='tip-title'>caption</title><p>A</p></tip>)
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

      expected = if type == 'notice' # exception pattern
                   <<-EOS.chomp
<#{type}-t><title aid:pstyle='#{type}-title'>#{type}1</title></#{type}-t><#{type}-t><title aid:pstyle='#{type}-title'>#{type}2</title></#{type}-t>
EOS
                 else
                   <<-EOS.chomp
<#{type}><title aid:pstyle='#{type}-title'>#{type}1</title></#{type}><#{type}><title aid:pstyle='#{type}-title'>#{type}2</title></#{type}>
EOS
                 end
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

      if type == 'notice' # exception pattern
        expected = <<-EOS.chomp
<#{type}-t><title aid:pstyle='#{type}-title'>#{type}2</title></#{type}-t><#{type}-t><title aid:pstyle='#{type}-title'>#{type}3</title></#{type}-t><#{type}-t><title aid:pstyle='#{type}-title'>#{type}4</title></#{type}-t><#{type}-t><title aid:pstyle='#{type}-title'>#{type}5</title></#{type}-t><#{type}-t><title aid:pstyle='#{type}-title'>#{type}6</title></#{type}-t>
EOS
      else
        expected = <<-EOS.chomp
<#{type}><title aid:pstyle='#{type}-title'>#{type}2</title></#{type}><#{type}><title aid:pstyle='#{type}-title'>#{type}3</title></#{type}><#{type}><title aid:pstyle='#{type}-title'>#{type}4</title></#{type}><#{type}><title aid:pstyle='#{type}-title'>#{type}5</title></#{type}><#{type}><title aid:pstyle='#{type}-title'>#{type}6</title></#{type}>
EOS
      end
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

      expected = if type == 'notice' # exception pattern
                   <<-EOS.chomp
<#{type}><ul><li aid:pstyle="ul-item">A</li></ul><ol><li aid:pstyle="ol-item" olnum="1" num="1">B</li></ol></#{type}><#{type}-t><title aid:pstyle='#{type}-title'>OMITEND1</title><list type='emlist'><pre>LIST
</pre></list></#{type}-t><#{type}-t><title aid:pstyle='#{type}-title'>OMITEND2</title></#{type}-t>
EOS
                 else
                   <<-EOS.chomp
<#{type}><ul><li aid:pstyle="ul-item">A</li></ul><ol><li aid:pstyle="ol-item" olnum="1" num="1">B</li></ol></#{type}><#{type}><title aid:pstyle='#{type}-title'>OMITEND1</title><list type='emlist'><pre>LIST
</pre></list></#{type}><#{type}><title aid:pstyle='#{type}-title'>OMITEND2</title></#{type}>
EOS
                 end
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

  def test_term
    actual = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal '<term><p>test1test1.5</p><p>test<i>2</i></p></term>', actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal '<term><p>test1 test1.5</p><p>test<i>2</i></p></term>', actual
  end

  def test_point
    actual = compile_block("//point[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></point-t>), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//point[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1 test1.5</p><p>test<i>2</i></p></point-t>), actual
  end

  def test_point_without_caption
    actual = compile_block("//point{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal '<point><p>test1test1.5</p><p>test<i>2</i></p></point>', actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//point{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal '<point><p>test1 test1.5</p><p>test<i>2</i></p></point>', actual
  end

  def test_emlist
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></list>), actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption></list>), actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlistnum'><caption aid:pstyle='emlistnum-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><span type='lineno'> 1: </span>test1\n<span type='lineno'> 2: </span>test1.5\n<span type='lineno'> 3: </span>\n<span type='lineno'> 4: </span>test<i>2</i>\n</pre></list>), actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlistnum'><pre><span type='lineno'> 1: </span>test1\n<span type='lineno'> 2: </span>test1.5\n<span type='lineno'> 3: </span>\n<span type='lineno'> 4: </span>test<i>2</i>\n</pre><caption aid:pstyle='emlistnum-title'>this is <b>test</b>&lt;&amp;&gt;_</caption></list>), actual
  end

  def test_emlist_listinfo
    @config['listinfo'] = true
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo></pre></list>
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>        test1
                test1.5

        test<i>2</i>
</pre></list>
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_4tab
    @config['tabwidth'] = 4
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>    test1
        test1.5

    test<i>2</i>
</pre></list>
EOS
    assert_equal expected, actual
  end

  def test_list
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1
test1.5

test<i>2</i>
</pre></codelist>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><pre>test1
test1.5

test<i>2</i>
</pre><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption></codelist>
EOS
    assert_equal expected, actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><span type='lineno'> 1: </span>test1
<span type='lineno'> 2: </span>test1.5
<span type='lineno'> 3: </span>
<span type='lineno'> 4: </span>test<i>2</i>
</pre></codelist>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><pre><span type='lineno'> 1: </span>test1
<span type='lineno'> 2: </span>test1.5
<span type='lineno'> 3: </span>
<span type='lineno'> 4: </span>test<i>2</i>
</pre><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption></codelist>
EOS
    assert_equal expected, actual
  end

  def test_listnum_linenum
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    actual = compile_block("//firstlinenum[100]\n//listnum[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><span type='lineno'>100: </span>test1
<span type='lineno'>101: </span>test1.5
<span type='lineno'>102: </span>
<span type='lineno'>103: </span>test<i>2</i>
</pre></codelist>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//firstlinenum[100]\n//listnum[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><pre><span type='lineno'>100: </span>test1
<span type='lineno'>101: </span>test1.5
<span type='lineno'>102: </span>
<span type='lineno'>103: </span>test<i>2</i>
</pre><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption></codelist>
EOS
    assert_equal expected, actual
  end

  def test_list_listinfo
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    @config['listinfo'] = true
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo></pre></codelist>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<codelist><pre><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo></pre><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption></codelist>
EOS
    assert_equal expected, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    expected = <<-EOS.chomp
<list type='cmd'><pre>lineA
lineB
</pre></list>
EOS
    assert_equal expected, actual

    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS.chomp
<list type='cmd'><caption aid:pstyle='cmd-title'>cap1</caption><pre>lineA
lineB
</pre></list>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS.chomp
<list type='cmd'><pre>lineA
lineB
</pre><caption aid:pstyle='cmd-title'>cap1</caption></list>
EOS
    assert_equal expected, actual
  end

  def test_source
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS.chomp
<source><caption>foo/bar/test.rb</caption><pre>foo
bar

buz
</pre></source>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS.chomp
<source><pre>foo
bar

buz
</pre><caption>foo/bar/test.rb</caption></source>
EOS
    assert_equal expected, actual
  end

  def test_source_empty_caption
    actual = compile_block("//source[]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS.chomp
<source><pre>foo
bar

buz
</pre></source>
EOS
    assert_equal expected, actual
  end

  def test_source_nil_caption
    actual = compile_block("//source{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS.chomp
<source><pre>foo
bar

buz
</pre></source>
EOS
    assert_equal expected, actual
  end

  def test_insn
    @config['listinfo'] = true
    actual = compile_block("//insn[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<insn><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo></insn>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//insn[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<insn><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle></insn>
EOS
    assert_equal expected, actual
  end

  def test_box
    @config['listinfo'] = true
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo></box>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<box><listinfo line="1" begin="1">test1
</listinfo><listinfo line="2">test1.5
</listinfo><listinfo line="3">
</listinfo><listinfo line="4" end="4">test<i>2</i>
</listinfo><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption></box>
EOS
    assert_equal expected, actual
  end

  def test_box_non_listinfo
    @config['listinfo'] = nil
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption>test1
test1.5

test<i>2</i>
</box>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS.chomp
<box>test1
test1.5

test<i>2</i>
<caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption></box>
EOS
    assert_equal expected, actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(<p align='right'>foobar</p><p align='right'>buz</p>), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(<p align='right'>foo bar</p><p align='right'>buz</p>), actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(<p align='center'>foobar</p><p align='center'>buz</p>), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(<p align='center'>foo bar</p><p align='center'>buz</p>), actual
  end

  def test_blankline
    actual = compile_block("//blankline\nfoo\n")
    assert_equal %Q(<p/><p>foo</p>), actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(<p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(<p aid:pstyle="noindent" noindent='1'>foo bar</p><p>foo2 bar2</p>), actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" /><caption>図1.1　sample photo</caption></img>), actual

    @config['caption_position']['image'] = 'top'
    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q(<img><caption>図1.1　sample photo</caption><Image href="file://images/chap1-sampleimg.png" /></img>), actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>図1.1　sample photo</caption></img>), actual
  end

  def test_image_with_metric2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2, html::class=sample, latex::ignore=params, idgxml::ostyle=object]{\n//}\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>図1.1　sample photo</caption></img>), actual
  end

  def test_indepimage
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" /><caption>sample photo</caption></img>), actual

    @config['caption_position']['image'] = 'top'
    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q(<img><caption>sample photo</caption><Image href="file://images/chap1-sampleimg.png" /></img>), actual
  end

  def test_indepimage_without_caption
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" /></img>), actual
  end

  def test_indepimage_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>sample photo</caption></img>), actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block(%Q(//indepimage[sampleimg][sample photo][scale=1.2, html::class="sample", latex::ignore=params, idgxml::ostyle="object"]\n))
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>sample photo</caption></img>), actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /></img>), actual
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
    expected = <<-EOS.chomp
<column id="column-1"><title aid:pstyle="column-title">prev column</title><?dtp level="9" section="prev column"?><p>inside prev column</p></column><column id="column-2"><title aid:pstyle="column-title">test</title><?dtp level="9" section="test"?><p>inside column</p></column>
EOS
    assert_equal expected, column_helper(review)
  end

  def test_column_2
    review = <<-EOS
===[column] test

inside column

=== next level
EOS
    expected = <<-EOS.chomp
<column id="column-1"><title aid:pstyle="column-title">test</title><?dtp level="9" section="test"?><p>inside column</p></column><title aid:pstyle="h3">next level</title><?dtp level="3" section="next level"?>
EOS

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

  def test_column_ref
    review = <<-EOS
===[column]{foo} test

inside column

=== next level

this is @<column>{foo}.
EOS
    expected = <<-EOS.chomp
<column id="column-1"><title aid:pstyle="column-title">test</title><?dtp level="9" section="test"?><p>inside column</p></column><title aid:pstyle="h3">next level</title><?dtp level="3" section="next level"?><p>this is <link href="column-1">コラム「test」</link>.</p>
EOS

    assert_equal expected, column_helper(review)

    @config['chapterlink'] = nil
    expected = <<-EOS.chomp
<column id="column-1"><title aid:pstyle="column-title">test</title><?dtp level="9" section="test"?><p>inside column</p></column><title aid:pstyle="h3">next level</title><?dtp level="3" section="next level"?><p>this is コラム「test」.</p>
EOS
    assert_equal expected, column_helper(review)
  end

  def test_column_in_aother_chapter_ref
    def @chapter.column_index
      item = Book::Index::Item.new('chap1|column', 1, 'column_cap')
      idx = Book::ColumnIndex.new
      idx.add_item(item)
      idx
    end

    actual = compile_inline('test @<column>{chap1|column} test2')
    expected = 'test <link href="column-1">コラム「column_cap」</link> test2'
    assert_equal expected, actual

    @config['chapterlink'] = nil
    actual = compile_inline('test @<column>{chap1|column} test2')
    expected = 'test コラム「column_cap」 test2'
    assert_equal expected, actual
  end

  def test_ul
    src = <<-EOS
  * AAA
  * BBB
EOS

    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA</li><li aid:pstyle="ul-item">BBB</li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_cont
    src = <<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS
    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA-AA</li><li aid:pstyle="ul-item">BBB-BB</li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA -AA</li><li aid:pstyle="ul-item">BBB -BB</li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest1
    src = <<-EOS
  * AAA
  ** AA
EOS

    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest2
    src = <<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest3
    src = <<-EOS
  ** AAA
  * AA
EOS

    assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_match(/too many \*\./, @log_io.string)
  end

  def test_ul_nest4
    src = <<-EOS
  * A
  ** B
  ** C
  *** D
  ** E
  * F
  ** G
EOS

    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">A<ul2><li aid:pstyle="ul-item">B</li><li aid:pstyle="ul-item">C<ul3><li aid:pstyle="ul-item">D</li></ul3></li><li aid:pstyle="ul-item">E</li></ul2></li><li aid:pstyle="ul-item">F<ul2><li aid:pstyle="ul-item">G</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ol
    src = <<-EOS
  3. AAA
  3. BBB
EOS

    expected = <<-EOS.chomp
<ol><li aid:pstyle="ol-item" olnum="1" num="3">AAA</li><li aid:pstyle="ol-item" olnum="2" num="3">BBB</li></ol>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_inline_unknown
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<img>{n}\n") }
    assert_match(/unknown image: n/, @log_io.string)

    @log_io.string = ''
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<fn>{n}\n") }
    assert_match(/unknown footnote: n/, @log_io.string)

    @log_io.string = ''
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<hd>{n}\n") }
    assert_match(/unknown headline: n/, @log_io.string)
    %w[list table column].each do |name|
      @log_io.string = ''
      assert_raises(ReVIEW::ApplicationError) { compile_block("@<#{name}>{n}\n") }
      assert_match(/unknown #{name}: n/, @log_io.string)
    end
    %w[chap chapref title].each do |name|
      @log_io.string = ''
      assert_raises(ReVIEW::ApplicationError) { compile_block("@<#{name}>{n}\n") }
      assert_match(/key not found: "n"/, @log_io.string)
    end
  end

  def test_inline_raw0
    assert_equal 'normal', compile_inline('@<raw>{normal}')
  end

  def test_inline_raw1
    assert_equal 'body', compile_inline('@<raw>{|idgxml|body}')
  end

  def test_inline_raw2
    assert_equal 'body', compile_inline('@<raw>{|idgxml, latex|body}')
  end

  def test_inline_raw3
    assert_equal '', compile_inline('@<raw>{|latex, html|body}')
  end

  def test_inline_raw4
    assert_equal '|idgxml body', compile_inline('@<raw>{|idgxml body}')
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline('@<raw>{|idgxml|nor\\nmal}')
  end

  def test_inline_imgref
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1, 'sample photo')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = %Q(<p><span type='image'>図1.1「sample photo」</span></p>)
    assert_equal expected, actual
  end

  def test_inline_imgref2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = %Q(<p><span type='image'>図1.1</span></p>)
    assert_equal expected, actual
  end

  def test_block_raw0
    actual = compile_block(%Q(//raw[<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw1
    actual = compile_block(%Q(//raw[|idgxml|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw2
    actual = compile_block(%Q(//raw[|idgxml, latex|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw3
    actual = compile_block(%Q(//raw[|latex, html|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw4
    actual = compile_block(%Q(//raw[|idgxml <>!"\\n& ]\n))
    expected = %Q(|idgxml <>!"\n& )
    assert_equal expected.chomp, actual
  end

  def test_comment
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント<]')
    assert_equal '<msg>コメント&lt;</msg>', actual
    actual = compile_block("//comment{\nA<>\nB&\n//}")
    assert_equal %Q(<msg>A&lt;&gt;\nB&amp;</msg>), actual
  end

  def test_inline_comment
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test  test2', actual
  end

  def test_inline_comment_for_draft
    @config['draft'] = true
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test <msg>コメント</msg> test2', actual
  end

  def test_texequation
    src = <<-EOS
//texequation{
e=mc^2
//}
EOS
    expected = %Q(<replace idref="texblock-1"><pre>e=mc^2</pre></replace>)
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
    expected = %Q(<p><span type='eq'>式1.1</span></p><equationblock><caption>式1.1　The Equivalence of Mass <i>and</i> Energy</caption><replace idref="texblock-1"><pre>e=mc^2</pre></replace></equationblock>)
    actual = compile_block(src)
    assert_equal expected, actual

    @config['caption_position']['equation'] = 'bottom'
    expected = %Q(<p><span type='eq'>式1.1</span></p><equationblock><replace idref="texblock-1"><pre>e=mc^2</pre></replace><caption>式1.1　The Equivalence of Mass <i>and</i> Energy</caption></equationblock>)
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_texequation_imgmath
    @config['math_format'] = 'imgmath'
    src = <<-EOS
//texequation{
p \\land \\bm{P} q
//}
EOS
    expected = %Q(<equationimage><Image href="file://images/_review_math/_gen_84291054a12d278ea05694c20fbbc8e974ec66fc13be801c01dca764faeecccb.png" /></equationimage>)
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_texequation_with_caption_imgmath
    @config['math_format'] = 'imgmath'
    src = <<-EOS
@<eq>{emc2}

//texequation[emc2][The Equivalence of Mass @<i>{and} Energy]{
e=mc^2
//}
EOS
    expected = %Q(<p><span type='eq'>式1.1</span></p><equationblock><caption>式1.1　The Equivalence of Mass <i>and</i> Energy</caption><equationimage><Image href="file://images/_review_math/_gen_882e99d99b276a2118a3894895b6da815a03261f4150148c99b932bec5355f25.png" /></equationimage></equationblock>)
    actual = compile_block(src)
    assert_equal expected, actual

    @config['caption_position']['equation'] = 'bottom'
    expected = %Q(<p><span type='eq'>式1.1</span></p><equationblock><equationimage><Image href="file://images/_review_math/_gen_882e99d99b276a2118a3894895b6da815a03261f4150148c99b932bec5355f25.png" /></equationimage><caption>式1.1　The Equivalence of Mass <i>and</i> Energy</caption></equationblock>)
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

    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item">UL1<ol><li aid:pstyle="ol-item" olnum="1" num="1">UL1-OL1</li><li aid:pstyle="ol-item" olnum="2" num="2">UL1-OL2</li></ol><ul><li aid:pstyle="ul-item">UL1-UL1</li><li aid:pstyle="ul-item">UL1-UL2</li></ul><dl><dt>UL1-DL1</dt><dd>UL1-DD1</dd><dt>UL1-DL2</dt><dd>UL1-DD2</dd></dl></li><li aid:pstyle="ul-item">UL2<p>UL2-PARA</p></li></ul>
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

    expected = <<-EOS.chomp
<ol><li aid:pstyle="ol-item" olnum="1" num="1">OL1<ol><li aid:pstyle="ol-item" olnum="1" num="1">OL1-OL1</li><li aid:pstyle="ol-item" olnum="2" num="2">OL1-OL2</li></ol><ul><li aid:pstyle="ul-item">OL1-UL1</li><li aid:pstyle="ul-item">OL1-UL2</li></ul><dl><dt>OL1-DL1</dt><dd>OL1-DD1</dd><dt>OL1-DL2</dt><dd>OL1-DD2</dd></dl></li><li aid:pstyle="ol-item" olnum="1" num="2">OL2<p>OL2-PARA</p></li></ol>
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

    expected = <<-EOS.chomp
<dl><dt>DL1</dt><dd><ol><li aid:pstyle="ol-item" olnum="1" num="1">DL1-OL1</li><li aid:pstyle="ol-item" olnum="2" num="2">DL1-OL2</li></ol><ul><li aid:pstyle="ul-item">DL1-UL1</li><li aid:pstyle="ul-item">DL1-UL2</li></ul><dl><dt>DL1-DL1</dt><dd>DL1-DD1</dd><dt>DL1-DL2</dt><dd>DL1-DD2</dd></dl></dd><dt>DL2</dt><dd>DD2<ul><li aid:pstyle="ul-item">DD2-UL1</li><li aid:pstyle="ul-item">DD2-UL2</li></ul><p>DD2-PARA</p></dd></dl>
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
    expected = <<-EOS.chomp
<ol><li aid:pstyle="ol-item" olnum="1" num="1">OL1<ol><li aid:pstyle="ol-item" olnum="1" num="1">OL1-OL1<ul><li aid:pstyle="ul-item">OL1-OL1-UL1</li></ul><p>OL1-OL1-PARA</p></li><li aid:pstyle="ol-item" olnum="1" num="2">OL1-OL2</li></ol><ul><li aid:pstyle="ul-item">OL1-UL1<dl><dt>OL1-UL1-DL1</dt><dd>OL1-UL1-DD1</dd></dl><p>OL1-UL1-PARA</p></li><li aid:pstyle="ul-item">OL1-UL2</li></ul></li></ol>
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end
end
