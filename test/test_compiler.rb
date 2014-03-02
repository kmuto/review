# encoding: utf-8

require 'test_helper'
require 'review'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'

class CompilerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = HTMLBuilder.new()
    @param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
      "stylesheet" => nil,  # for HTMLBuilder
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(Book::Base.new(nil), 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)

    def @compiler.compile_command(name, args, lines)
      args
    end
  end

  def test_parse_args
    args = compile_blockelem("//dummy[foo][bar]\n")
    assert_equal ["foo","bar"], args
  end

  def test_parse_args_with_brace1
    args = compile_blockelem("//dummy[fo[\\][\\]o][bar]")
    assert_equal ["fo[][]o","bar"], args
  end

  def test_parse_args_with_brace2
    args = compile_blockelem("//dummy[f\\]o\\]o][bar]")
    assert_equal ["f]o]o","bar"], args
  end

  def test_parse_args_with_backslash
    args = compile_blockelem("//dummy[foo][bar\\buz]")
    assert_equal ["foo","bar\\buz"], args
  end

  def test_parse_args_with_backslash2
    args = compile_blockelem("//dummy[foo][bar\\#\\[\\!]")
    assert_equal ["foo","bar\\#\\[\\!"], args
  end

  def test_parse_args_with_backslash3
    args = compile_blockelem("//dummy[foo][bar\\\\buz]")
    assert_equal ["foo","bar\\buz"], args
  end
end

