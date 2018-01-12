require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/idgxmlbuilder'
require 'review/i18n'

class IDGXMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = IDGXMLBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['tableopt'] = '10'
    @book = Book::Base.new(nil)
    @book.config = @config
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

  def test_emtable
    actual = compile_block("//emtable[foo]{\nA\n//}\n//emtable{\nA\n//}")
    assert_equal %Q(<table><caption>foo</caption><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody></table><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="1" aid:tcols="1"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="28.345">A</td></tbody></table>), actual
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
    actual = compile_inline('@<ruby>{coffin, bed}')
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

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    assert_equal %Q(<dl><dt>foo</dt><dd>foo.</dd></dl><p>para</p><dl><dt>foo</dt><dd>foo.</dd></dl><ol><li aid:pstyle="ol-item" olnum="1" num="1">bar</li></ol><dl><dt>foo</dt><dd>foo.</dd></dl><ul><li aid:pstyle="ul-item">bar</li></ul>), actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal '<p>foobar</p>', actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(<p inlist="1">foobar</p>), actual
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal '<quote><p>foobar</p><p>buz</p></quote>', actual
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

  def test_term
    actual = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal '<term><p>test1test1.5</p><p>test<i>2</i></p></term>', actual
  end

  def test_point
    actual = compile_block("//point[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></point-t>), actual
  end

  def test_point_without_caption
    actual = compile_block("//point{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal '<point><p>test1test1.5</p><p>test<i>2</i></p></point>', actual
  end

  def test_emlist
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></list>), actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlistnum'><caption aid:pstyle='emlistnum-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><span type='lineno'> 1: </span>test1\n<span type='lineno'> 2: </span>test1.5\n<span type='lineno'> 3: </span>\n<span type='lineno'> 4: </span>test<i>2</i>\n</pre></list>), actual
  end

  def test_emlist_listinfo
    @config['listinfo'] = true
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></list>), actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>        test1\n                test1.5\n\n        test<i>2</i>\n</pre></list>), actual
  end

  def test_emlist_with_4tab
    @config['tabwidth'] = 4
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q(<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>    test1\n        test1.5\n\n    test<i>2</i>\n</pre></list>), actual
  end

  def test_list
    def @chapter.list(_id)
      Book::ListIndex::Item.new('samplelist', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></codelist>), actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::ListIndex::Item.new('samplelist', 1)
    end
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><span type='lineno'> 1: </span>test1\n<span type='lineno'> 2: </span>test1.5\n<span type='lineno'> 3: </span>\n<span type='lineno'> 4: </span>test<i>2</i>\n</pre></codelist>), actual
  end

  def test_listnum_linenum
    def @chapter.list(_id)
      Book::ListIndex::Item.new('samplelist', 1)
    end
    actual = compile_block("//firstlinenum[100]\n//listnum[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><span type='lineno'>100: </span>test1\n<span type='lineno'>101: </span>test1.5\n<span type='lineno'>102: </span>\n<span type='lineno'>103: </span>test<i>2</i>\n</pre></codelist>), actual
  end

  def test_list_listinfo
    def @chapter.list(_id)
      Book::ListIndex::Item.new('samplelist', 1)
    end
    @config['listinfo'] = true
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></codelist>), actual
  end

  def test_insn
    @config['listinfo'] = true
    actual = compile_block("//insn[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<insn><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></insn>), actual
  end

  def test_box
    @config['listinfo'] = true
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></box>), actual
  end

  def test_box_non_listinfo
    @config['listinfo'] = nil
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q(<box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption>test1\ntest1.5\n\ntest<i>2</i>\n</box>), actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(<p align='right'>foobar</p><p align='right'>buz</p>), actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(<p align='center'>foobar</p><p align='center'>buz</p>), actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(<p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>), actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" /><caption>図1.1　sample photo</caption></img>), actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>図1.1　sample photo</caption></img>), actual
  end

  def test_image_with_metric2
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2, html::class=sample, latex::ignore=params, idgxml::ostyle=object]{\n//}\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>図1.1　sample photo</caption></img>), actual
  end

  def test_indepimage
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" /><caption>sample photo</caption></img>), actual
  end

  def test_indepimage_without_caption
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" /></img>), actual
  end

  def test_indepimage_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>sample photo</caption></img>), actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block(%Q(//indepimage[sampleimg][sample photo][scale=1.2, html::class="sample", latex::ignore=params, idgxml::ostyle="object"]\n))
    assert_equal %Q(<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>sample photo</caption></img>), actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
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
<column id="column-1"><title aid:pstyle="column-title">test</title><?dtp level="9" section="test"?><p>inside column</p></column><title aid:pstyle="h3">next level</title><?dtp level="3" section="next level"?><p>this is コラム「test」.</p>
EOS

    assert_equal expected, column_helper(review)
  end

  def test_column_in_aother_chapter_ref
    def @chapter.column_index
      items = [Book::ColumnIndex::Item.new('chap1|column', 1, 'column_cap')]
      Book::ColumnIndex.new(items)
    end

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
  * BBB
  ** BB
EOS

    expected = <<-EOS.chomp
<ul><li aid:pstyle="ul-item"><ul2><li aid:pstyle="ul-item">AAA</li></ul2></li><li aid:pstyle="ul-item">AA</li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
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
      item = Book::ImageIndex::Item.new('sampleimg', 1, 'sample photo')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block "@<imgref>{sampleimg}\n"
    expected = %Q(<p><span type='image'>図1.1「sample photo」</span></p>)
    assert_equal expected, actual
  end

  def test_inline_imgref2
    def @chapter.image(_id)
      item = Book::NumberlessImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block "@<imgref>{sampleimg}\n"
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
    actual = compile_block('//comment[コメント]')
    assert_equal '<msg>コメント</msg>', actual
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
end
