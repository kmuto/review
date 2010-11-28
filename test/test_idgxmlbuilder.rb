# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/idgxmlbuilder'

class IDGXMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = IDGXMLBuilder.new()
    @param = {
      "secnolevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "nolf" => true,
      "tableopt" => "10",
      "subdirmode" => nil,
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Chapter.new(nil, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h1">第1章　this is test.</title><?dtp level="1" section="第1章　this is test."?>|, @builder.raw_result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h1">this is test.</title><?dtp level="1" section="this is test."?>|, @builder.raw_result
  end

  def test_headline_level2
    @builder.headline(2,"test","this is test.")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h2">1.1　this is test.</title><?dtp level="2" section="1.1　this is test."?>|, @builder.raw_result
  end

  def test_headline_level3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h3">this is test.</title><?dtp level="3" section="this is test."?>|, @builder.raw_result
  end


  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><title id="test" aid:pstyle="h3">1.0.1　this is test.</title><?dtp level="3" section="1.0.1　this is test."?>|, @builder.raw_result
  end

  def test_label
    @builder.label("label_test")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><label id='label_test' />|, @builder.raw_result
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|<a linkurl='http://github.com'>GitHub</a>|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|<a linkurl='http://github.com'>http://github.com</a>|, ret
  end

  def test_inline_raw
    ret = @builder.inline_raw("@<tt>{inline}")
    assert_equal %Q|@<tt>{inline}|, ret
  end

  def test_inline_in_table
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "------------", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td aid:table="cell" aid:theader="1" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, @builder.raw_result
  end

  def test_inline_in_table_without_header
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody xmlns:aid5="http://ns.adobe.com/AdobeInDesign/5.0/" aid:table="table" aid:trows="2" aid:tcols="2"><td aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>1</b></td><td aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>2</i></td><td aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><b>3</b></td><td aid:table="cell" aid:crows="1" aid:ccols="1" aid:ccolwidth="14.2450142450142"><i>4</i>&lt;&gt;&amp;</td></tbody></table>|, @builder.raw_result
  end

  def test_inline_in_table_without_cellwidth
    @param["tableopt"] = nil
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "------------", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody><tr type="header"><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, @builder.raw_result
    @param["tableopt"] = 10
  end

  def test_inline_in_table_without_header_and_cellwidth
    @param["tableopt"] = nil
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><table><tbody><tr><b>1</b>\t<i>2</i></tr><tr type="lastline"><b>3</b>\t<i>4</i>&lt;&gt;&amp;</tr></tbody></table>|, @builder.raw_result
    @param["tableopt"] = 10
  end

  def test_inline_br
    ret = @builder.inline_br("")
    assert_equal %Q|\n|, ret
  end

  def test_inline_uchar
    ret = @builder.compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, ret
  end

  def test_inline_ruby
    ret = @builder.compile_ruby("coffin", "bed")
    assert_equal %Q|<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>coffin</aid:rb><aid:rt>bed</aid:rt></aid:ruby></GroupRuby>|, ret
  end

  def test_inline_kw
    ret = @builder.compile_inline("@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}")
    assert_equal %Q|<keyword>ISO（International Organization for Standardization）</keyword><index value="ISO" /><index value="International Organization for Standardization" /> <keyword>Ruby&lt;&gt;</keyword><index value="Ruby&lt;&gt;" />|, ret
  end

  def test_inline_maru
    ret = @builder.compile_inline("@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}")
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
    ret = @builder.compile_inline("@<m>{\\sin} @<m>{\\frac{1\\}{2\\}}")
    assert_equal %Q|<replace idref="texinline-1"><pre>\\sin</pre></replace> <replace idref="texinline-2"><pre>\\frac{1}{2}</pre></replace>|, ret
  end

  def test_paragraph
    lines = ["foo","bar"]
    @builder.paragraph(lines)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p>foobar</p>|, @builder.raw_result
  end

  def test_tabbed_paragraph
    lines = ["\tfoo","bar"]
    @builder.paragraph(lines)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p inlist="1">foobar</p>|, @builder.raw_result
  end

  def test_quote
    lines = ["foo","bar","","buz"]
    @builder.quote(lines)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><quote><p>foobar</p><p>buz</p></quote>|, @builder.raw_result
  end

  def test_quote_deprecated
    lines = ["foo","","buz"]
    ReVIEW.book.param["deprecated-blocklines"] = true
    @builder.quote(lines)
    ReVIEW.book.param["deprecated-blocklines"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><quote>foo\n\nbuz</quote>|, @builder.raw_result
  end

  def test_note
    @builder.note(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><note><title aid:pstyle='note-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></note>|, @builder.raw_result
  end

  def test_memo
    @builder.memo(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><memo><title aid:pstyle='memo-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></memo>|, @builder.raw_result
  end

  def test_term
    @builder.term(["test1", "test1.5", "", "test<i>2</i>"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><term><p>test1test1.5</p><p>test<i>2</i></p></term>|, @builder.raw_result
  end

  def test_term_deprecated
    ReVIEW.book.param["deprecated-blocklines"] = true
    @builder.term(["test1", "test1.5", "", "test<i>2</i>"])
    ReVIEW.book.param["deprecated-blocklines"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><term>test1\ntest1.5\n\ntest<i>2</i></term>|, @builder.raw_result
  end

  def test_notice
    @builder.notice(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><notice-t><title aid:pstyle='notice-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></notice-t>|, @builder.raw_result
  end

  def test_notice_without_caption
    @builder.notice(["test1", "test1.5", "", "test<i>2</i>"], nil)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><notice><p>test1test1.5</p><p>test<i>2</i></p></notice>|, @builder.raw_result
  end

  def test_point
    @builder.point(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><point-t><title aid:pstyle='point-title'>this is <b>test</b>&lt;&amp;&gt;_</title><p>test1test1.5</p><p>test<i>2</i></p></point-t>|, @builder.raw_result
  end

  def test_point_without_caption
    @builder.point(["test1", "test1.5", "", "test<i>2</i>"], nil)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><point><p>test1test1.5</p><p>test<i>2</i></p></point>|, @builder.raw_result
  end

  def test_insn
    @param["listinfo"] = true
    @builder.insn(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    @param["listinfo"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><insn><floattitle type="insn">this is <b>test</b>&lt;&amp;&gt;_</floattitle><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></insn>|, @builder.raw_result
  end

  def test_box
    @param["listinfo"] = true
    @builder.box(["test1", "test1.5", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    @param["listinfo"] = nil
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><box><caption aid:pstyle="box-title">this is <b>test</b>&lt;&amp;&gt;_</caption><listinfo line="1" begin="1">test1\n</listinfo><listinfo line="2">test1.5\n</listinfo><listinfo line="3">\n</listinfo><listinfo line="4" end="4">test<i>2</i>\n</listinfo></box>|, @builder.raw_result
  end

  def test_flushright
    @builder.flushright(["foo", "bar", "","buz"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p align='right'>foobar</p><p align='right'>buz</p>|, @builder.raw_result
  end

  def test_noindent
    @builder.noindent
    @builder.paragraph(["foo", "bar"])
    @builder.paragraph(["foo2", "bar2"])
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><p aid:pstyle="noindent" noindent='1'>foobar</p><p>foo2bar2</p>|, @builder.raw_result
  end

  def test_raw
    @builder.raw("<&>\\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><&>\n|, @builder.raw_result
  end

  def test_image
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo",nil)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png"  /><caption>図1.1　sample photo</caption></img>|, @builder.raw_result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>図1.1　sample photo</caption></img>|, @builder.raw_result
  end

  def test_indepimage
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo",nil)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png"  /><caption>sample photo</caption></img>|, @builder.raw_result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg",nil,nil)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png"  /></img>|, @builder.raw_result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /><caption>sample photo</caption></img>|, @builder.raw_result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg",nil,"scale=1.2")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><img><Image href="file://images/chap1-sampleimg.png" scale="1.2" /></img>|, @builder.raw_result
  end

end
