require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/epubbuilder'

class EPUBBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = EPUBBuilder.new()
    @param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, EPUBBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
      "stylesheet" => nil,  # for EPUBBuilder
    }
    compiler = ReVIEW::Compiler.new(@builder)
    compiler.setParameter(@param)
    chapter = Chapter.new(nil, 1, '-', nil, StringIO.new)
    chapter.setParameter(@param)
    location = Location.new(nil, nil)
    @builder.bind(compiler, chapter, location)
  end

  def test_headline_level1
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<h1 id='test'><a id="h1" />第1章　this is test.</h1>\n|, @builder.raw_result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<h1 id='test'><a id="h1" />this is test.</h1>\n|, @builder.raw_result
  end

  def test_headline_level2
    @builder.headline(2,"test","this is test.")
    assert_equal %Q|\n<h2 id='test'><a id="h1-1" />1.1　this is test.</h2>\n|, @builder.raw_result
  end

  def test_headline_level3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\n<h3 id='test'><a id="h1-0-1" />this is test.</h3>\n|, @builder.raw_result
  end


  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\n<h3 id='test'><a id="h1-0-1" />1.0.1　this is test.</h3>\n|, @builder.raw_result
  end

  def test_label
    @builder.label("label_test")
    assert_equal %Q|<a id="label_test" />\n|, @builder.raw_result
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|<a href="http://github.com" class="link">GitHub</a>|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|<a href="http://github.com" class="link">http://github.com</a>|, ret
  end

  def test_inline_raw
    ret = @builder.inline_raw("@<tt>{inline}")
    assert_equal %Q|@&lt;tt&gt;{inline}|, ret
  end

  def test_inline_in_table
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "------------", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<table>\n<tr><th><b>1</b></th><th><i>2</i></th></tr>\n<tr><td><b>3</b></td><td><i>4</i>&lt;&gt;&amp;</td></tr>\n</table>\n|, @builder.raw_result
  end
end
