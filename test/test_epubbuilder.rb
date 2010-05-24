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
    assert_equal %Q|<h1 id='test'>第1章　this is test.</h1>\n|, @builder.raw_result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<h1 id='test'>this is test.</h1>\n|, @builder.raw_result
  end

  def test_headline_level2
    @builder.headline(2,"test","this is test.")
    assert_equal %Q|\n<h2 id='test'>1.1　this is test.</h2>\n|, @builder.raw_result
  end

  def test_headline_level3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\n<h3 id='test'>this is test.</h3>\n|, @builder.raw_result
  end


  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\n<h3 id='test'>1.0.1　this is test.</h3>\n|, @builder.raw_result
  end
end
