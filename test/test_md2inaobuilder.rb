# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/md2inaobuilder'
require 'review/i18n'

class MD2INAOBuilderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = MD2INAOBuilder.new()
    @config = {
      "secnolevel" => 2, # for IDGXMLBuilder, HTMLBuilder
      "stylesheet" => nil, # for HTMLBuilder
    }
    @book = Book::Base.new(".")
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup("ja")
  end

  def test_paragraph
    actual = compile_block("Hello, world!")
    assert_equal "　Hello, world!\n\n", actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    assert_equal "!!! cmd\nlineA\nlineB\n\n", actual
  end

  def test_dlist
    actual = compile_block(": foo\n  foo.\n  bar.\n")
    assert_equal "<dl>\n<dt>foo</dt>\n<dd>foo.bar.</dd>\n</dl>\n", actual
  end

  def test_list
    actual = compile_block(<<-EOS)
//list[name][caption]{
AAA
BBB
//}
    EOS

    assert_equal <<-EOS, actual
```
●リスト1::caption

AAA
BBB
```
    EOS
  end

  def test_comment
    actual = compile_block("//comment{\nHello, world!\n//}\n")
    assert_equal "<span class=\"red\">\nHello, world!\n</span>\n", actual
  end
end
