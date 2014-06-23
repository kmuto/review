# encoding: utf-8

require 'test_helper'
require 'review'
require 'review/compiler'
require 'review/book'
require 'review/idgxmlbuilder'
require 'review/i18n'

class IDGXMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = IDGXMLBuilder.new()
    @config = {
      "secnolevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "nolf" => true,
      "tableopt" => "10"
    }
    ReVIEW.book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(Book::Base.new(nil), 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    result = @builder.headline(1,"test","this is test.")
    assert_equal %Q|<title id="test" aid:pstyle="h1">第1章　this is test.</title><?dtp level="1" section="第1章　this is test."?>|, result
  end

  def test_headline_level1_without_secno
    @config["secnolevel"] = 0
    result = @builder.headline(1,"test","this is test.")
    assert_equal %Q|<title id="test" aid:pstyle="h1">this is test.</title><?dtp level="1" section="this is test."?>|, result
  end

  def test_headline_level2
    result = @builder.headline(2,"test","this is test.")
    assert_equal %Q|<title id="test" aid:pstyle="h2">1.1　this is test.</title><?dtp level="2" section="1.1　this is test."?>|, result
  end

  def test_headline_level3
    result = @builder.headline(3,"test","this is test.")
    assert_equal %Q|<title id="test" aid:pstyle="h3">this is test.</title><?dtp level="3" section="this is test."?>|, result
  end


  def test_headline_level3_with_secno
    @config["secnolevel"] = 3
    result = @builder.headline(3,"test","this is test.")
    assert_equal %Q|<title id="test" aid:pstyle="h3">1.0.1　this is test.</title><?dtp level="3" section="1.0.1　this is test."?>|, result
  end

  def test_label
    result = @builder.label("label_test")
    assert_equal %Q|<label id='label_test' />|, result
  end

  def test_inline_ref
    ret = compile_inline("@<ref>{外部参照<>&}")
    assert_equal %Q|<ref idref='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</ref>|, ret
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|<a linkurl='http://github.com'>GitHub</a>|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|<a linkurl='http://github.com'>http://github.com</a>|, ret
  end

  def test_inline_href
    ret = compile_inline("@<href>{http://github.com, Git\\,Hub}")
    assert_equal %Q|<a linkurl='http://github.com'>Git,Hub</a>|, ret
  end

  def test_inline_raw
    ret = @builder.inline_raw("@<tt>{inline}")
    assert_equal %Q|@<tt>{inline}|, ret
  end

  def test_inline_in_table
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "------------", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, ret
  end

  def test_inline_in_table_without_header
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td xyh="1,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td xyh="2,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, ret
  end

  def test_inline_in_table_without_cellwidth
    @config["tableopt"] = nil
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "------------", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<table><tbody><tr type="header"><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, ret
    @config["tableopt"] = 10
  end

  def test_inline_in_table_without_header_and_cellwidth
    @config["tableopt"] = nil
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<table><tbody><tr><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, ret
    @config["tableopt"] = 10
  end

  def test_inline_br
    ret = @builder.inline_br("")
    assert_equal %Q|\n|, ret
  end

  def test_inline_uchar
    ret = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, ret
  end

  def test_inline_ruby
    ret = @builder.compile_ruby("coffin", "bed")
    assert_equal %Q|<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>coffin</aid:rb><aid:rt>bed</aid:rt></aid:ruby></GroupRuby>|, ret
  end

  def test_inline_kw
    ret = compile_inline("@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}")
    assert_equal %Q|<keyword>ISO（International Organization for Standardization）</keyword><index value="ISO" /><index value="International Organization for Standardization" /> <keyword>Ruby&lt;&gt;</keyword><index value="Ruby&lt;&gt;" />|, ret
  end

  def test_inline_maru
    ret = compile_inline("@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}")
    assert_equal %Q|&#x2460;&#x2473;&#x24b6;&#x24e9;|, ret
  end

  def test_inline_ttb
    ret = @builder.inline_ttb("test * <>\"")
    assert_equal %Q|<tt style='bold'>test * &lt;&gt;&quot;</tt><index value='test ESCAPED_ASTERISK &lt;&gt;&quot;' />|, ret
  end

  def test_inline_ttbold
    ret = @builder.inline_ttbold("test * <>\"")
    assert_equal %Q|<tt style='bold'>test * &lt;&gt;&quot;</tt><index value='test ESCAPED_ASTERISK &lt;&gt;&quot;' />|, ret
  end

  def test_inline_balloon
    ret = @builder.inline_balloon("@maru[1]test")
    assert_equal %Q|<balloon>&#x2460;test</balloon>|, ret
  end

  def test_inline_m
    ret = compile_inline("@<m>{\\sin} @<m>{\\frac{1\\}{2\\}}")
    assert_equal %Q|<replace idref="texinline-1"><pre>\\sin</pre></replace> <replace idref="texinline-2"><pre>\\frac{1}{2}</pre></replace>|, ret
  end

  def test_paragraph
    lines = ["foo","bar"]
    result = @builder.paragraph(lines)
    assert_equal %Q|<p>foobar</p>|, result
  end

  def test_tabbed_paragraph
    lines = ["\tfoo","bar"]
    result = @builder.paragraph(lines)
    assert_equal %Q|<p inlist="1">foobar</p>|, result
  end

  def test_quote
    lines = ["foo","bar","","buz"]
    result = @builder.quote(lines)
    assert_equal %Q|<quote><p>foobar</p><p>buz</p></quote>|, result
  end

  def test_quote_deprecated
    lines = ["foo","","buz"]
    ReVIEW.book.config["deprecated-blocklines"] = true
    result = @builder.quote(lines)
    ReVIEW.book.config["deprecated-blocklines"] = nil
    assert_equal %Q|<quote>foo\n\nbuz</quote>|, result
  end

  ## XXX block content should be escaped.
  def test_note
    ##result = @builder.note(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    result = compile_blockelem("//note[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest<i>2</i>\n//}\n")
    assert_equal %Q|<note><title aid:pstyle='note-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test&lt;i&gt;2&lt;/i&gt;</p></note>|, result
  end

  ## XXX block content should be escaped.
  def test_memo
    ##result = @builder.memo(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    result = compile_blockelem("//memo[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<memo><title aid:pstyle='memo-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></memo>|, result
  end

  def test_term
    result = @builder.term(["test1", "test1.5", "", "test<i>2</i>"])
    assert_equal %Q|<term><p>test1test1.5</p><p>test<i>2</i></p></term>|, result
  end

  def test_term_deprecated
    ReVIEW.book.config["deprecated-blocklines"] = true
    result = @builder.term(["test1", "test1.5", "", "test<i>2</i>"])
    ReVIEW.book.config["deprecated-blocklines"] = nil
    assert_equal %Q|<term>test1\ntest1.5\n\ntest<i>2</i></term>|, result
  end

  def test_notice
    ##result = @builder.notice(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    result = compile_blockelem("//notice[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<notice-t><title aid:pstyle='notice-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></notice-t>|, result
  end

  def test_notice_without_caption
    result = compile_blockelem("//notice{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<notice><p>test1test1.5</p><p>test<i>2</i></p></notice>|, result
  end

  def test_point
    result = compile_blockelem("//point[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></point-t>|, result
  end

  def test_point_without_caption
    result = compile_blockelem("//point{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<point><p>test1test1.5</p><p>test<i>2</i></p></point>|, result
  end

  def test_emlist
    result = compile_blockelem("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></list>|, result
  end

  def test_emlist_listinfo
    @config["listinfo"] = true
    result = @builder.emlist(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></list>|, result
  end

  def test_emlist_with_tab
    ## @builder.emlist(["\ttest1", "\t\ttest1.5", "", "\ttest<i>2</i>"], "this is @<b>{test}<&>_")
    result = compile_blockelem("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>        test1\n                test1.5\n\n        test<i>2</i>\n</pre></list>|, result
  end

  def test_emlist_with_4tab
    @builder.instance_eval{@tabwidth=4}
    ## @builder.emlist(["\ttest1", "\t\ttest1.5", "", "\ttest<i>2</i>"], "this is @<b>{test}<&>_")
    result = compile_blockelem("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q|<list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>    test1\n        test1.5\n\n    test<i>2</i>\n</pre></list>|, result
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    result = compile_blockelem("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    ##@builder.list(["test1", "test1.5", "", "test<i>2</i>"], "samplelist", "this is @<b>{test}<&>_")
    assert_equal %Q|<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></codelist>|, result
  end

  def test_list_listinfo
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    @config["listinfo"] = true
    result = compile_blockelem("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></codelist>|, result
  end

  def test_insn
    @config["listinfo"] = true
    result = compile_blockelem("//insn[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @config["listinfo"] = nil
    assert_equal %Q|<insn><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></insn>|, result
  end

  def test_box
    @config["listinfo"] = true
    result = compile_blockelem("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @config["listinfo"] = nil
    assert_equal %Q|<box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></box>|, result
  end

  def test_flushright
    result = @builder.flushright(["foo", "bar", "","buz"])
    assert_equal %Q|<p align='right'>foobar</p><p align='right'>buz</p>|, result
  end

  def test_centering
    result = @builder.centering(["foo", "bar", "","buz"])
    assert_equal %Q|<p align='center'>foobar</p><p align='center'>buz</p>|, result
  end

  def test_noindent
    result = ""
    @builder.noindent
    result << @builder.paragraph(["foo", "bar"])
    result << @builder.paragraph(["foo2", "bar2"])
    assert_equal %Q|<p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>|, result
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.image_image("sampleimg","sample photo",nil)
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" /><caption>図1.1　sample photo</caption></img>|, result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.image_image("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>図1.1　sample photo</caption></img>|, result
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.image_image("sampleimg","sample photo","scale=1.2, html::class=\"sample\", latex::ignore=params, idgxml::ostyle=object")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>図1.1　sample photo</caption></img>|, result
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.indepimage("sampleimg","sample photo",nil)
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" /><caption>sample photo</caption></img>|, result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.indepimage("sampleimg",nil,nil)
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" /></img>|, result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.indepimage("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>sample photo</caption></img>|, result
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.indepimage("sampleimg","sample photo","scale=1.2, html::class=\"sample\", latex::ignore=params, idgxml::ostyle=\"object\"")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>sample photo</caption></img>|, result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = @builder.indepimage("sampleimg",nil,"scale=1.2")
    assert_equal %Q|<img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /></img>|, result
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
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><column id="column-1"><title aid:pstyle="column-title">prev column</title><p>inside prev column</p></column><column id="column-2"><title aid:pstyle="column-title">test</title><p>inside column</p></column></doc>
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
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><column id="column-1"><title aid:pstyle="column-title">test</title><p>inside column</p></column><title aid:pstyle=\"h3\">next level</title><?dtp level="3" section="next level"?></doc>
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
<ul><li aid:pstyle="ul-item">AAA</li><li aid:pstyle="ul-item">BBB</li></ul>
EOS
    ul_helper(src, expect.chomp)
  end

  def test_ul_cont
    src =<<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS

    expect =<<-EOS
<ul><li aid:pstyle="ul-item">AAA-AA</li><li aid:pstyle="ul-item">BBB-BB</li></ul>
EOS
    ul_helper(src, expect.chomp)
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
EOS

    expect =<<-EOS
<ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li></ul>
EOS
    ul_helper(src, expect.chomp)
  end

  def test_ul_nest2
    src =<<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expect =<<-EOS
<ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    ul_helper(src, expect.chomp)
  end

  def test_ul_nest3
    src =<<-EOS
  ** AAA
  * AA
  * BBB
  ** BB
EOS

    expect =<<-EOS
<ul><li aid:pstyle="ul-item"><ul2><li aid:pstyle="ul-item">AAA</li></ul2></li><li aid:pstyle="ul-item">AA</li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    ul_helper(src, expect.chomp)
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

    expect =<<-EOS
<ul><li aid:pstyle="ul-item">A<ul2><li aid:pstyle="ul-item">B</li><li aid:pstyle="ul-item">C<ul3><li aid:pstyle="ul-item">D</li></ul3></li><li aid:pstyle="ul-item">E</li></ul2></li><li aid:pstyle="ul-item">F<ul2><li aid:pstyle="ul-item">G</li></ul2></li></ul>
EOS
    ul_helper(src, expect.chomp)
  end

  def test_ol
    src =<<-EOS
  3. AAA
  3. BBB
EOS

    expect =<<-EOS
<ol><li aid:pstyle="ol-item" olnum="1" num="3">AAA</li><li aid:pstyle="ol-item" olnum="2" num="3">BBB</li></ol>
EOS
    ol_helper(src, expect.chomp)
  end

  def test_inline_raw0
    assert_equal "normal", @builder.inline_raw("normal")
  end

  def test_inline_raw1
    assert_equal "body", @builder.inline_raw("|idgxml|body")
  end

  def test_inline_raw2
    assert_equal "body", @builder.inline_raw("|idgxml, latex|body")
  end

  def test_inline_raw3
    assert_equal "", @builder.inline_raw("|latex, html|body")
  end

  def test_inline_raw4
    assert_equal "|idgxml body", @builder.inline_raw("|idgxml body")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", @builder.inline_raw("|idgxml|nor\\nmal")
  end

  def test_block_raw0
    result = compile_blockelem("//raw[<>!\"\\n& ]\n")
    expect = %Q(<>!\"\n& )
    assert_equal expect.chomp, result
  end

  def test_block_raw1
    result = compile_blockelem("//raw[|idgxml|<>!\"\\n& ]\n")
    expect = %Q(<>!\"\n& )
    assert_equal expect.chomp, result
  end

  def test_block_raw2
    result = compile_blockelem("//raw[|idgxml, latex|<>!\"\\n& ]\n")
    expect = %Q(<>!\"\n& )
    assert_equal expect.chomp, result
  end

  def test_block_raw3
    result = compile_blockelem("//raw[|latex, html|<>!\"\\n& ]\n")
    expect = %Q()
    assert_equal expect.chomp, result
  end

  def test_block_raw4
    result = compile_blockelem("//raw[|idgxml <>!\"\\n& ]\n")
    expect = %Q(|idgxml <>!\"\n& )
    assert_equal expect.chomp, result
  end
end
