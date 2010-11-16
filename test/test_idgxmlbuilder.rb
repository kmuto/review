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
    compiler = ReVIEW::Compiler.new(@builder)
    chapter = Chapter.new(nil, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(compiler, chapter, location)
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

  def test_inline_br
    ret = @builder.inline_br("")
    assert_equal %Q|\n|, ret
  end

  def test_inline_uchar
    ret = @builder.compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, ret
  end

  def test_quote
    lines = ["foo","bar","buz"]
    @builder.quote(lines)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><quote>foo\nbar\nbuz</quote>|, @builder.raw_result
  end

  def test_blockquote
    lines = ["foo","","buz"]
    @builder.blockquote(lines)
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><quote><p>foo</p>\n<p>buz</p></quote>|, @builder.raw_result
  end

  def test_memo
    @builder.memo(["test1", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><memo><title aid:pstyle='memo-title'>this is <b>test</b>&lt;&amp;&gt;_</title>test1\ntest<i>2</i></memo>|, @builder.raw_result
  end

  def test_raw
    @builder.raw("<&>\\n")
    assert_equal %Q|<?xml version="1.0" encoding="UTF-8"?>\n<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/"><&>\n|, @builder.raw_result
  end
end
