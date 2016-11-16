# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'
require 'review/htmlbuilder'

class CompilerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = HTMLBuilder.new()
    @param = {
      "secnolevel" => 2, # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
      "stylesheet" => nil, # for HTMLBuilder
    }
    @book = Book::Base.new(nil)
    @book.config = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)

    def @compiler.compile_command(name, args, lines, node)
      args
    end

  end

  def test_parse_args
    args = compile_blockelem("//dummy[foo][bar]\n", false)
    assert_equal ["foo","bar"], args.parse_args(:doc,:doc)
  end

  def test_parse_args_with_brace1
    args = compile_blockelem("//dummy[fo[\\][\\]o][bar]", false)
    assert_equal ["fo[][]o","bar"], args.parse_args(:doc, :doc)
  end

  def test_parse_args_with_brace2
    args = compile_blockelem("//dummy[f\\]o\\]o][bar]", false)
    assert_equal ["f]o]o","bar"], args.parse_args(:doc, :doc)
  end

  def test_parse_args_with_backslash
    args = compile_blockelem("//dummy[foo][bar\\buz]", false)
    assert_equal ["foo","bar\\buz"], args.parse_args(:doc, :doc)
  end

  def test_parse_args_with_backslash2
    args = compile_blockelem("//dummy[foo][bar\\#\\[\\!]", false)
    assert_equal ["foo","bar\\#\\[\\!"], args.parse_args(:doc, :doc)
  end

  def test_parse_args_with_backslash3
    args = compile_blockelem("//dummy[foo][bar\\\\buz]", false)
    assert_equal ["foo","bar\\buz"], args.parse_args(:doc, :doc)
  end

  def test_compile_inline
    def @compiler.inline_ruby(*args)
      return args
    end
    args = compile_inline("@<ruby>{abc}",false)
    assert_equal "abc", args.content[0].content.to_doc
  end

  def test_inline_ruby
#    def @compiler.inline_ruby(*args)
#      return args
#    end
    args = compile_inline("@<ruby>{foo,bar}",false)
    assert_equal "foo", args.content[0].content[0].to_doc
    assert_equal "bar", args.content[0].content[1].to_doc
    args = compile_inline("@<ruby>{foo\\,\\,,\\,bar\\,buz}", false)
    assert_equal "foo,,", args.content[0].content[0].to_doc
    assert_equal ",bar,buz", args.content[0].content[1].to_doc
  end

  def test_compile_inline_backslash
    def @compiler.inline_dummy(*args)
      return args
    end
    Compiler.definline :dummy
    args = compile_inline("@<dummy>{abc\\d\\#a}", false)
    assert_equal "abc\\d\\#a", args.content[0].content.to_doc
  end
end

