# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../book_test_helper'
require 'review/ast/compiler'
require 'review/renderer/idgxml_renderer'
require 'review/book'
require 'review/i18n'

class IdgxmlRendererTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['tableopt'] = '10'
    @book = Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    I18n.setup('ja')
  end

  def compile_block(src)
    @chapter.content = src
    compiler = ReVIEW::AST::Compiler.for_chapter(@chapter)
    ast = compiler.compile_to_ast(@chapter)
    renderer = ReVIEW::Renderer::IdgxmlRenderer.new(@chapter)
    result = renderer.render(ast)
    # Strip XML declaration and root doc tags to match expected output format
    result = result.sub(/\A<\?xml[^>]+\?><doc[^>]*>/, '').sub(/<\/doc>\s*\z/, '').strip
    result
  end

  def compile_inline(src)
    result = compile_block(src)
    # For inline tests, also strip the paragraph tags if present
    result = result.sub(/\A<p>/, '').sub(/<\/p>\z/, '').strip if result.start_with?('<p>')
    result
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

  def test_emlist
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></list>), actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption></list>), actual
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal '<quote><p>foobar</p><p>buz</p></quote>', actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal '<quote><p>foo bar</p><p>buz</p></quote>', actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(<p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(<p aid:pstyle="noindent" noindent='1'>foo bar</p><p>foo2 bar2</p>), actual
  end

  def test_blankline
    actual = compile_block("//blankline\nfoo\n")
    assert_equal %Q(<p/><p>foo</p>), actual
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
end
