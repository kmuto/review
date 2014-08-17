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
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h1">第1章　this is test.</title><?dtp level="1" section="第1章　this is test."?>|, result
  end

  def test_headline_level1_without_secno
    @config["secnolevel"] = 0
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h1">this is test.</title><?dtp level="1" section="this is test."?>|, result
  end

  def test_headline_level2
    result = compile_block("=={test} this is test.\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h2">1.1　this is test.</title><?dtp level="2" section="1.1　this is test."?>|, result
  end

  def test_headline_level3
    result = compile_block("==={test} this is test.\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h3">this is test.</title><?dtp level="3" section="this is test."?>|, result
  end


  def test_headline_level3_with_secno
    @config["secnolevel"] = 3
    result = compile_block("==={test} this is test.\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h3">1.0.1　this is test.</title><?dtp level="3" section="1.0.1　this is test."?>|, result
  end

  def test_label
    result = compile_block("//label[label_test]\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><label id='label_test' />|, result
  end

  def test_inline_ref
    result = compile_inline("@<ref>{外部参照<>&}")
    assert_equal %Q|<ref idref='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</ref>|, result
  end

  def test_href
    result = compile_inline("@<href>{http://github.com,GitHub}")
    assert_equal %Q|<a linkurl='http://github.com'>GitHub</a>|, result
  end

  def test_href_without_label
    result = compile_inline("@<href>{http://github.com}")
    assert_equal %Q|<a linkurl='http://github.com'>http://github.com</a>|, result
  end

  def test_inline_href
    result = compile_inline("@<href>{http://github.com, Git\\,Hub}")
    assert_equal %Q|<a linkurl='http://github.com'>Git,Hub</a>|, result
  end

  def test_inline_raw
    result = compile_inline("@<raw>{@<tt>{inline\}}")
    assert_equal %Q|@<tt>{inline}|, result
  end

  def test_inline_in_table
    result = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td xyh="2,1,1" aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td xyh="1,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td xyh="2,2,1" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, result
  end

  def test_inline_in_table_without_header
    result = compile_block("//table{\n@<b>{1}\t@<i>{2}\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td xyh="1,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td xyh="2,1,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td xyh="1,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td xyh="2,2,0" aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, result
  end

  def test_inline_in_table_without_cellwidth
    @config["tableopt"] = nil
    result = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody><tr type="header"><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, result
    @config["tableopt"] = 10
  end

  def test_inline_in_table_without_header_and_cellwidth
    @config["tableopt"] = nil
    result = compile_block("//table{\n@<b>{1}\t@<i>{2}\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody><tr><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, result
    @config["tableopt"] = 10
  end

  def test_inline_br
    result = compile_inline("@<br>{}")
    assert_equal %Q|\n|, result
  end

  def test_inline_uchar
    result = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, result
  end

  def test_inline_ruby
    result = compile_inline("@<ruby>{coffin, bed}")
    assert_equal %Q|<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>coffin</aid:rb><aid:rt>bed</aid:rt></aid:ruby></GroupRuby>|, result
  end

  def test_inline_kw
    result = compile_inline("@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}")
    assert_equal %Q|<keyword>ISO（International Organization for Standardization）</keyword><index value="ISO" /><index value="International Organization for Standardization" /> <keyword>Ruby&lt;&gt;</keyword><index value="Ruby&lt;&gt;" />|, result
  end

  def test_inline_maru
    result = compile_inline("@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}")
    assert_equal %Q|&#x2460;&#x2473;&#x24b6;&#x24e9;|, result
  end

  def test_inline_ttb
    result = compile_inline("@<ttb>{test * <>\"}")
    assert_equal %Q|<tt style='bold'>test * &lt;&gt;&quot;</tt><index value='test ESCAPED_ASTERISK &lt;&gt;&quot;' />|, result
  end

  def test_inline_ttbold
    result = compile_inline("@<ttbold>{test * <>\"}")
    assert_equal %Q|<tt style='bold'>test * &lt;&gt;&quot;</tt><index value='test ESCAPED_ASTERISK &lt;&gt;&quot;' />|, result
  end

  def test_inline_balloon
    result = compile_inline("@<balloon>{@maru[1]test}")
    assert_equal %Q|<balloon>&#x2460;test</balloon>|, result
  end

  def test_inline_m
    result = compile_inline("@<m>{\\sin} @<m>{\\frac{1\\}{2\\}}")
    assert_equal %Q|<replace idref="texinline-1"><pre>\\sin</pre></replace> <replace idref="texinline-2"><pre>\\frac{1}{2}</pre></replace>|, result
  end

  def test_paragraph
    result = compile_block("foo\nbar\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p>foobar</p>|, result
  end

  def test_tabbed_paragraph
    result = compile_block("\tfoo\nbar\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p inlist="1">foobar</p>|, result
  end

  def test_quote
    result = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><quote><p>foobar</p><p>buz</p></quote>|, result
  end

  def test_quote_deprecated
    ReVIEW.book.config["deprecated-blocklines"] = true
    result = compile_block("//quote{\nfoo\n\nbuz\n//}\n")
    ReVIEW.book.config["deprecated-blocklines"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><quote>foo\n\nbuz</quote>|, result
  end

  def test_note
    result = compile_block("//note[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><note><title aid:pstyle='note-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></note>|, result
  end

  def test_memo
    result = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><memo><title aid:pstyle='memo-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></memo>|, result
  end

  def test_term
    result = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><term><p>test1test1.5</p><p>test<i>2</i></p></term>|, result
  end

  def test_term_deprecated
    ReVIEW.book.config["deprecated-blocklines"] = true
    result = compile_block("//term{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    ReVIEW.book.config["deprecated-blocklines"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><term>test1\ntest1.5\n\ntest<i>2</i></term>|, result
  end

  def test_notice
    result = compile_block("//notice[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><notice-t><title aid:pstyle='notice-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></notice-t>|, result
  end

  def test_notice_without_caption
    result = compile_block("//notice{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><notice><p>test1test1.5</p><p>test<i>2</i></p></notice>|, result
  end

  def test_point
    result = compile_block("//point[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></point-t>|, result
  end

  def test_point_without_caption
    result = compile_block("//point{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><point><p>test1test1.5</p><p>test<i>2</i></p></point>|, result
  end

  def test_emlist
    result = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></list>|, result
  end

  def test_emlist_listinfo
    @config["listinfo"] = true
    result = compile_block("//emlist[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></list>|, result
  end

  def test_emlist_with_tab
    result = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>        test1\n                test1.5\n\n        test<i>2</i>\n</pre></list>|, result
  end

  def test_emlist_with_4tab
    @config["tabwidth"] = 4
    result = compile_block("//emlist[this is @<b>{test}<&>_]{\n\ttest1\n\t\ttest1.5\n\n\ttest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><list type='emlist'><caption aid:pstyle='emlist-title'>this is <b>test</b>&lt;&amp;&gt;_</caption><pre>    test1\n        test1.5\n\n    test<i>2</i>\n</pre></list>|, result
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    result = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre>test1\ntest1.5\n\ntest<i>2</i>\n</pre></codelist>|, result
  end

  def test_list_listinfo
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    @config["listinfo"] = true
    result = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><codelist><caption>リスト1.1　this is <b>test</b>&lt;&amp;&gt;_</caption><pre><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></pre></codelist>|, result
  end

  def test_insn
    @config["listinfo"] = true
    result = compile_block("//insn[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @config["listinfo"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><insn><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></insn>|, result
  end

  def test_box
    @config["listinfo"] = true
    result = compile_block("//box[this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    @config["listinfo"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></box>|, result
  end

  def test_flushright
    result = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p align='right'>foobar</p><p align='right'>buz</p>|, result
  end

  def test_centering
    result = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p align='center'>foobar</p><p align='center'>buz</p>|, result
  end

  def test_noindent
    result = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>|, result
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" /><caption>図1.1　sample photo</caption></img>|, result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>図1.1　sample photo</caption></img>|, result
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo][scale=1.2, html::class=sample, latex::ignore=params, idgxml::ostyle=object]{\n//}\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>図1.1　sample photo</caption></img>|, result
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" /><caption>sample photo</caption></img>|, result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" /></img>|, result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>sample photo</caption></img>|, result
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo][scale=1.2, html::class=\"sample\", latex::ignore=params, idgxml::ostyle=\"object\"]\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" ostyle="object" /><caption>sample photo</caption></img>|, result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /></img>|, result
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
    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><column id="column-1"><title aid:pstyle="column-title">prev column</title><p>inside prev column</p></column><column id="column-2"><title aid:pstyle="column-title">test</title><p>inside column</p></column>
EOS
    assert_equal expect, column_helper(review)
  end

  def test_column_2
    review =<<-EOS
===[column] test

inside column

=== next level
EOS
    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><column id="column-1"><title aid:pstyle="column-title">test</title><p>inside column</p></column><title aid:pstyle=\"h3\">next level</title><?dtp level="3" section="next level"?>
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

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ul><li aid:pstyle="ul-item">AAA</li><li aid:pstyle="ul-item">BBB</li></ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_cont
    src =<<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ul><li aid:pstyle="ul-item">AAA-AA</li><li aid:pstyle="ul-item">BBB-BB</li></ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
EOS

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li></ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest2
    src =<<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ul><li aid:pstyle="ul-item">AAA<ul2><li aid:pstyle="ul-item">AA</li></ul2></li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest3
    src =<<-EOS
  ** AAA
  * AA
  * BBB
  ** BB
EOS

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ul><li aid:pstyle="ul-item"><ul2><li aid:pstyle="ul-item">AAA</li></ul2></li><li aid:pstyle="ul-item">AA</li><li aid:pstyle="ul-item">BBB<ul2><li aid:pstyle="ul-item">BB</li></ul2></li></ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
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

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ul><li aid:pstyle="ul-item">A<ul2><li aid:pstyle="ul-item">B</li><li aid:pstyle="ul-item">C<ul3><li aid:pstyle="ul-item">D</li></ul3></li><li aid:pstyle="ul-item">E</li></ul2></li><li aid:pstyle="ul-item">F<ul2><li aid:pstyle="ul-item">G</li></ul2></li></ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ol
    src =<<-EOS
  3. AAA
  3. BBB
EOS

    expect =<<-EOS.chomp
<?xml version="1.0" encoding="UTF-8"?>
<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><ol><li aid:pstyle="ol-item" olnum="1" num="3">AAA</li><li aid:pstyle="ol-item" olnum="2" num="3">BBB</li></ol>
EOS
    result = compile_block(src)
    assert_equal expect, result
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
    result = compile_block("//raw[<>!\"\\n& ]\n")
    expect = %Q(<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw1
    result = compile_block("//raw[|idgxml|<>!\"\\n& ]\n")
    expect = %Q(<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><>!\"\n& )
    assert_equal expect.chomp, result
  end

  def test_block_raw2
    result = compile_block("//raw[|idgxml, latex|<>!\"\\n& ]\n")
    expect = %Q(<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><>!\"\n& )
    assert_equal expect.chomp, result
  end

  def test_block_raw3
    result = compile_block("//raw[|latex, html|<>!\"\\n& ]\n")
    expect = %Q(<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">)
    assert_equal expect.chomp, result
  end

  def test_block_raw4
    result = compile_block("//raw[|idgxml <>!\"\\n& ]\n")
    expect = %Q(<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">|idgxml <>!\"\n& )
    assert_equal expect.chomp, result
  end

end
