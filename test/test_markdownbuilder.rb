# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'
require 'review/i18n'

class MARKDOWNBuilderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = MARKDOWNBuilder.new()
    @config = {
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "stylesheet" => nil,  # for HTMLBuilder
    }
    ReVIEW.book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(Book::Base.new(nil), 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_quote
    lines = ["foo", "bar", "","buz"]
    result = @builder.quote(lines)
    assert_equal %Q|\n> foobar\n> \n> buz\n\n|, @builder.raw_result
  end

  def test_inline_em
    assert_equal "test*foo*abc", @builder.compile_inline("test@<em>{foo}abc")
  end

  def test_inline_strong
    assert_equal "test**foo**abc", @builder.compile_inline("test@<strong>{foo}abc")
  end

  def test_ul
    src =<<-EOS
  * AAA
  * BBB
EOS
    expect = "\n* AAA\n* BBB\n\n"
    ul_helper(src, expect)
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
  *** A
EOS
    expect = "\n* AAA\n  * AA\n    * A\n\n"
    ul_helper(src, expect)
  end

  def test_cmd
    @builder.cmd(["lineA","lineB"])
    assert_equal "```\nlineA\nlineB\n```\n", @builder.raw_result
  end

  def test_table
    @builder.table(["testA\ttestB","------------","contentA\tcontentB"])
    assert_equal "|testA|testB|\n|:--|:--|\n|contentA|contentB|\n\n", @builder.raw_result
  end
end
