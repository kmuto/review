# frozen_string_literal: true

require 'test_helper'
require 'review/builder'

require 'review/book'

class MockCompiler
  def text(s)
    [:text, s]
  end
end

class BuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @b = Builder.new
    chap = ReVIEW::Book::Chapter.new(nil, nil, '-', nil)
    @b.bind(MockCompiler.new, chap, nil)
  end

  def test_initialize
    assert Builder.new
  end

  def test_bind
    b = Builder.new
    chap = ReVIEW::Book::Chapter.new(ReVIEW::Book::Base.new, nil, '-', nil)
    assert_nothing_raised do
      b.bind(nil, chap, nil)
    end
  end

  def test_result
    b = Builder.new
    assert_raises(NoMethodError) do # XXX: OK?
      b.result
    end

    b = Builder.new
    chapter = ReVIEW::Book::Chapter.new(ReVIEW::Book::Base.new, nil, '-', nil)
    b.bind(nil, chapter, nil)
    assert_equal '', b.result
  end

  def test_print_and_puts
    b = Builder.new
    assert_raises(NoMethodError) do # XXX: OK?
      b.print ''
    end
    assert_raises(NoMethodError) do # XXX: OK?
      b.puts ''
    end
  end

  def test_not_implemented_methods
    ex = NoMethodError # XXX: OK?
    %i[list_header list_body listnum_body source_header source_body image_image image_dummy table_header table_begin tr th table_end compile_ruby compile_kw compile_href bibpaper_header bibpaper_bibpaper inline_hd_chap].each do |m|
      b = Builder.new
      assert_raises(ex) { b.__send__(m) }
    end
  end

  def test_compile_inline
    text = 'abc'
    assert_equal [:text, text], @b.compile_inline(text)
  end

  def test_inline_ruby
    def @b.compile_ruby(base, ruby)
      [base, ruby]
    end
    str = @b.inline_ruby('foo,bar')
    assert_equal str, ['foo', 'bar']
    str = @b.inline_ruby('    foo    ,    bar  ')
    assert_equal str, ['foo', 'bar']
    str = @b.inline_ruby('foo\\,\\,,\\,bar,buz')
    assert_equal str, ['foo,,', ',bar,buz']
  end

  def test_compile_inline_backslash
    text = 'abc\\d\\#a'
    assert_equal [:text, text], @b.compile_inline(text)
  end

  def test_inline_missing_ref
    b = Builder.new
    chapter = ReVIEW::Book::Chapter.new(ReVIEW::Book::Base.new, 1, 'chap1', nil, StringIO.new)
    b.bind(nil, chapter, nil)
    e = assert_raises(ReVIEW::ApplicationError) { b.inline_list('unknown|list1') }
    assert_equal 'unknown list: unknown|list1', e.message
    e = assert_raises(ReVIEW::ApplicationError) { b.inline_table('unknown|table1') }
    assert_equal 'unknown table: unknown|table1', e.message
    e = assert_raises(ReVIEW::ApplicationError) { b.inline_img('unknown|img1') }
    assert_equal 'unknown image: unknown|img1', e.message
    e = assert_raises(ReVIEW::ApplicationError) { b.inline_column('unknown|column1') }
    assert_equal 'unknown column: unknown|column1', e.message
    e = assert_raises(ReVIEW::ApplicationError) { b.inline_fn('unknown|footnote1') }
    assert_equal 'unknown footnote: unknown|footnote1', e.message
    e = assert_raises(ReVIEW::ApplicationError) { b.inline_endnote('endnote1') }
    assert_equal 'unknown endnote: endnote1', e.message
  end

  def test_nest_error
    b = XBuilder.new
    b.children = nil
    assert_equal '', b.solve_nest('')
    b.children = ['dl']
    e = assert_raises(ReVIEW::ApplicationError) { b.solve_nest('') }
    assert_equal ': //beginchild of dl misses //endchild', e.message
    b.children = ['ul', 'dl', 'ol']
    e = assert_raises(ReVIEW::ApplicationError) { b.solve_nest('') }
    assert_equal ': //beginchild of ol,dl,ul misses //endchild', e.message

    assert_equal "\u0001→/ol←\u0001", b.endchild
    assert_equal "\u0001→/dl←\u0001", b.endchild
    assert_equal "\u0001→/ul←\u0001", b.endchild
    e = assert_raises(ReVIEW::ApplicationError) { b.endchild }
    assert_equal ": //endchild is shown, but any opened //beginchild doesn't exist", e.message
  end

  class XBuilder < Builder
    attr_accessor :children

    def puts(s)
      s
    end
  end
end
