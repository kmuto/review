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
    chap = ReVIEW::Book::Chapter.new(ReVIEW::Book::Base.load, nil, '-', nil)
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
    chapter = ReVIEW::Book::Chapter.new(ReVIEW::Book::Base.load, nil, '-', nil)
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
    str = @b.inline_ruby('foo\\,\\,,\\,bar,buz')
    assert_equal str, ['foo,,', ',bar,buz']
  end

  def test_compile_inline_backslash
    text = 'abc\\d\\#a'
    assert_equal [:text, text], @b.compile_inline(text)
  end

  class XBuilder < Builder
    def list_header(id, caption)
    end

    def list_body(lines)
    end

    def listnum_body(lines)
    end

    def source_header(caption)
    end

    def source_body(lines)
    end
  end
end
