# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/idgxmlbuilder'
require 'review/i18n'

class IDGXMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = IDGXMLBuilder.new()
    @config = ReVIEW::Configure.values
    @config.merge!({
      "secnolevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "nolf" => true,
      "tableopt" => "10"
    })
    @book = Book::Base.new(nil)
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<title id="test" aid:pstyle="h1">第1章　this is test.</title><?dtp level="1" section="第1章　this is test."?>|, actual
  end

  def test_headline_level1_without_secno
    @config["secnolevel"] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<title id="test" aid:pstyle="h1">this is test.</title><?dtp level="1" section="this is test."?>|, actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q|<title id="test" aid:pstyle="h2">1.1　this is test.</title><?dtp level="2" section="1.1　this is test."?>|, actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q|<title id="test" aid:pstyle="h3">this is test.</title><?dtp level="3" section="this is test."?>|, actual
  end


  def test_headline_level3_with_secno
    @config["secnolevel"] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q|<title id="test" aid:pstyle="h3">1.0.1　this is test.</title><?dtp level="3" section="1.0.1　this is test."?>|, actual
  end

  def test_label
    actual = compile_block("//label[label_test]\n")
    assert_equal %Q|<label id='label_test' />|, actual
  end

  def test_inline_ref
    actual = compile_inline("@<ref>{外部参照<>&}")
    assert_equal %Q|<ref idref='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</ref>|, actual
  end

  def test_href
    actual = compile_inline("@<href>{http://github.com,GitHub}")
    assert_equal %Q|<a linkurl='http://github.com'>GitHub</a>|, actual
  end

  def test_href_without_label
    actual = compile_inline("@<href>{http://github.com}")
    assert_equal %Q|<a linkurl='http://github.com'>http://github.com</a>|, actual
  end

  def test_inline_href
    actual = compile_inline("@<href>{http://github.com, Git\\,Hub}")
    assert_equal %Q|<a linkurl='http://github.com'>Git,Hub</a>|, actual
  end

  def test_inline_raw
    actual = compile_inline("@<raw>{@<tt>{inline\}}")
    assert_equal %Q|@<tt>{inline}|, actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, actual
  end

  def test_inline_in_table_without_header
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td xyh="1,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td xyh="2,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, actual
  end

  def test_inline_in_table_without_cellwidth
    @config["tableopt"] = nil
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<table><tbody><tr type="header"><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, actual
    @config["tableopt"] = 10
  end

  def test_inline_in_table_without_header_and_cellwidth
    @config["tableopt"] = nil
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<table><tbody><tr><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, actual
    @config["tableopt"] = 10
  end

  def test_inline_br
    actual = compile_inline("@<br>{}")
    assert_equal %Q|\n|, actual
  end

  def test_inline_uchar
    actual = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, actual
  end

  def test_inline_ruby
    actual = compile_inline("@<ruby>{coffin, bed}")
    assert_equal %Q|<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>coffin</aid:rb><aid:rt>bed</aid:rt></aid:ruby></GroupRuby>|, actual
  end

  def test_inline_kw
    actual = compile_inline("@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}")
    assert_equal %Q|<keyword>ISO（International Organization for Standardization）</keyword><index value="ISO" /><index value="International Organization for Standardization" /> <keyword>Ruby&lt;&gt;</keyword><index value="Ruby&lt;&gt;" />|, actual
  end

  def test_inline_maru
    actual = compile_inline("@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}")
    assert_equal %Q|&#x2460;&#x2473;&#x24b6;&#x24e9;|, actual
  end

  def test_inline_ttb
    actual = compile_inline("@<ttb>{test * <>\"}")
    assert_equal %Q|<tt style='bold'>test * &lt;&gt;&quot;</tt>|, actual
  end

  def test_inline_ttbold
    actual = compile_inline("@<ttbold>{test * <>\"}")
    assert_equal %Q|<tt style='bold'>test * &lt;&gt;&quot;</tt>|, actual
  end

  def test_inline_balloon
    actual = compile_inline("@<balloon>{@maru[1]test}")
    assert_equal %Q|<balloon>&#x2460;test</balloon>|, actual
  end

  def test_inline_m
    actual = compile_inline("@<m>{\\sin} @<m>{\\frac{1\\}{2\\}}")
    assert_equal %Q|<replace idref="texinline-1"><pre>\\sin</pre></replace> <replace idref="texinline-2"><pre>\\frac{1}{2}</pre></replace>|, actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal %Q|<p>foobar</p>|, actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q|<p inlist="1">foobar</p>|, actual
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<quote><p>foobar</p><p>buz</p></quote>|, actual
  end

  def test_quote_deprecated
    @book.config["deprecated-blocklines"] = true
    actual = compile_block("//quote{\nfoo\n\nbuz\n//}\n")
    @book.config["deprecated-blocklines"] = nil
    assert_equal %Q|<quote>foo\n\nbuz</quote>|, actual
  end

  def test_note
    actual = compile_block("//note[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<note><title aid:pstyle='note-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></note>|, actual
  end

  def test_memo
    actual = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<memo><title aid:pstyle='memo-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></memo>|, actual
  end

  def test_term
    actual = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<term><p>test1test1.5</p><p>test<i>2</i></p></term>|, actual
  end

  def test_term_deprecated
    @book.config["deprecated-blocklines"] = true
    actual = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @book.config["deprecated-blocklines"] = nil
    assert_equal %Q|<term>test1\ntest1.5\n\ntest<i>2</i></term>|, actual
  end

  def test_notice
    actual = compile_block("//notice[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<notice-t><title aid:pstyle='notice-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></notice-t>|, actual
  end

  def test_notice_without_caption
    actual = compile_block("//notice{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<notice><p>test1test1.5</p><p>test<i>2</i></p></notice>|, actual
  end

  def test_point
    actual = compile_block("//point[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></point-t>|, actual
  end

  def test_point_without_caption
    actual = compile_block("//point{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<point><p>test1test1.5</p><p>test<i>2</i></p></point>|, actual
  end

  def test_emlist
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></list>|, actual
  end

  def test_emlist_listinfo
    @config["listinfo"] = true
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></list>|, actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>        test1\n                test1.5\n\n        test<i>2</i>\n</pre></list>|, actual
  end

  def test_emlist_with_4tab
    @config["tabwidth"] = 4
    actual = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>    test1\n        test1.5\n\n    test<i>2</i>\n</pre></list>|, actual
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></codelist>|, actual
  end

  def test_list_listinfo
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    @config["listinfo"] = true
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></codelist>|, actual
  end

  def test_insn
    @config["listinfo"] = true
    actual = compile_block("//insn[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @config["listinfo"] = nil
    assert_equal %Q|<insn><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></insn>|, actual
  end

  def test_box
    @config["listinfo"] = true
    actual = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @config["listinfo"] = nil
    assert_equal %Q|<box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></box>|, actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<p align='right'>foobar</p><p align='right'>buz</p>|, actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<p align='center'>foobar</p><p align='center'>buz</p>|, actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q|<p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>|, actual
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" /><caption>図1.1　sample photo</caption></img>|, actual
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>図1.1　sample photo</caption></img>|, actual
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2, html::class=sample, latex::ignore=params, idgxml::ostyle=object]{\n//}\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>図1.1　sample photo</caption></img>|, actual
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" /><caption>sample photo</caption></img>|, actual
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" /></img>|, actual
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>sample photo</caption></img>|, actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2, html::class=\"sample\", latex::ignore=params, idgxml::ostyle=\"object\"]\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>sample photo</caption></img>|, actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /></img>|, actual
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
    expected =<<-EOS.chomp
<column id="column-1"><title aid:pstyle="column-title">prev column</title><p>inside prev column</p></column><column id="column-2"><title aid:pstyle="column-title">test</title><p>inside column</p></column>
EOS
    assert_equal expected, column_helper(review)
  end

  def test_column_2
    review =<<-EOS
===[column] test

inside column

=== next level
EOS
    expected =<<-EOS.chomp
<column id="column-1"><title aid:pstyle="column-title">test</title><p>inside column</p></column><title aid:pstyle=\"h3\">next level</title><?dtp level="3" section="next level"?>
EOS

    assert_equal expected, column_helper(review)
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

    expected =<<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA</li><li aid:pstyle="ul-item">BBB</li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_cont
    src =<<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS

    expected =<<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA-AA</li><li aid:pstyle="ul-item">BBB-BB</li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
EOS

    expected =<<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest2
    src =<<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expected =<<-EOS.chomp
<ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest3
    src =<<-EOS
  ** AAA
  * AA
  * BBB
  ** BB
EOS

    expected =<<-EOS.chomp
<ul><li aid:pstyle="ul-item"><ul2><li aid:pstyle="ul-item">AAA</li></ul2></li><li aid:pstyle="ul-item">AA</li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest4
    src =<<-EOS
  * A
  ** B
  ** C
  *** D
  ** E
  * F
  ** G
EOS

    expected =<<-EOS.chomp
<ul><li aid:pstyle="ul-item">A<ul2><li aid:pstyle="ul-item">B</li><li aid:pstyle="ul-item">C<ul3><li aid:pstyle="ul-item">D</li></ul3></li><li aid:pstyle="ul-item">E</li></ul2></li><li aid:pstyle="ul-item">F<ul2><li aid:pstyle="ul-item">G</li></ul2></li></ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ol
    src =<<-EOS
  3. AAA
  3. BBB
EOS

    expected =<<-EOS.chomp
<ol><li aid:pstyle="ol-item" olnum="1" num="3">AAA</li><li aid:pstyle="ol-item" olnum="2" num="3">BBB</li></ol>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_inline_raw0
    assert_equal "normal", compile_inline("@<raw>{normal}")
  end

  def test_inline_raw1
    assert_equal "body", compile_inline("@<raw>{|idgxml|body}")
  end

  def test_inline_raw2
    assert_equal "body", compile_inline("@<raw>{|idgxml, latex|body}")
  end

  def test_inline_raw3
    assert_equal "", compile_inline("@<raw>{|latex, html|body}")
  end

  def test_inline_raw4
    assert_equal "|idgxml body", compile_inline("@<raw>{|idgxml body}")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline("@<raw>{|idgxml|nor\\nmal}")
  end

  def test_block_raw0
    actual = compile_block("//raw[<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected, actual
  end

  def test_block_raw1
    actual = compile_block("//raw[|idgxml|<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw2
    actual = compile_block("//raw[|idgxml, latex|<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw3
    actual = compile_block("//raw[|latex, html|<>!\"\\n& ]\n")
    expected = %Q()
    assert_equal expected.chomp, actual
  end

  def test_block_raw4
    actual = compile_block("//raw[|idgxml <>!\"\\n& ]\n")
    expected = %Q(|idgxml <>!\"\n& )
    assert_equal expected.chomp, actual
  end

end
