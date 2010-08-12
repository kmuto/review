require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'

class LATEXBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = LATEXBuilder.new()
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
    assert_equal %Q|\\chapter{this is test.}\n|, @builder.result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|\\chapter*{this is test.}\n|, @builder.result
  end

  def test_headline_level2
    @builder.headline(2,"test","this is test.")
    assert_equal %Q|\\section{this is test.}\n|, @builder.result
  end

  def test_headline_level3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\\subsection*{this is test.}\n|, @builder.result
  end


  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\\subsection{this is test.}\n|, @builder.result
  end

  def test_label
    @builder.label("label_test")
    assert_equal %Q|\\label{label_test}\n|, @builder.result
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|\\href{http://github.com}{GitHub}|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|\\href{http://github.com}{http://github.com}|, ret
  end

  def test_href_with_underscore
    ret = @builder.compile_href("http://example.com/aaa/bbb", "AAA_BBB")
    assert_equal %Q|\\href{http://example.com/aaa/bbb}{AAA\\symbol{\"5F}BBB}|, ret
  end

  def test_normal_text
    ret = @builder.text("abcde. xyz123.")
    assert_equal %Q|abcde. xyz123.|, ret
  end

  def test_escaped_text
    ret = @builder.text("a<>b&c\de. xyz[]123.")
    assert_equal %Q|a<>b&c\de. xyz[]123.|, ret
  end

  def test_escape
    ret = @builder.instance_eval{escape("a<>b&c\\de. xyz[]123.")}
    assert_equal %Q|a\\symbol{"3C}\\symbol{"3E}b\\&c\\symbol{"5C}de. xyz[]123.|, ret
  end

end
