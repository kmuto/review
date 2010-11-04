# encoding: utf-8

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
    @b.bind(MockCompiler.new, nil, nil)
  end

  def test_initialize
    assert Builder.new
  end

  def test_bind
    b = Builder.new
    assert_nothing_raised do
      b.bind(nil, nil, nil)
    end
  end

  def test_result
    b = Builder.new
    assert_raises(NoMethodError) do # XXX: OK?
      b.result
    end

    b = Builder.new
    b.bind(nil, nil, nil)
    assert_equal '', b.result
  end

  def test_print_and_puts
    b = Builder.new
    assert_raises(NoMethodError) do # XXX: OK?
      b.print ""
    end
    assert_raises(NoMethodError) do # XXX: OK?
      b.puts ""
    end

    utf8_str = "\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xe3\x81\x88\xe3\x81\x8a" # "あいうえお"
    eucjp_str = "\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa"
    sjis_str = "\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8"
    jis_str = "\x1b\x24\x42\x24\x22\x24\x24\x24\x26\x24\x28\x24\x2a\x1b\x28\x42"

    [
      ['EUC', eucjp_str],
      ['SJIS', sjis_str],
      ['JIS', jis_str],
      ['jis', jis_str],
      ['jIs', jis_str],
      ['XYZ', utf8_str],
    ].each do |enc, expect|
      params = {"outencoding" => enc}

      [
        [:print, utf8_str, expect],
        [:puts,  utf8_str, "#{expect}\n"],
        [:print, "#{utf8_str}\n", "#{expect}\n"],
        [:puts,  "#{utf8_str}\n", "#{expect}\n"],
      ].each do |m, instr, expstr|
        b = Builder.new
        b.bind(nil, nil, nil)
        ReVIEW.book.param = params
        b.__send__(m, instr)
        assert_equal expstr, b.result
      end
    end
  end

  def test_not_implemented_methods
    ex = NoMethodError # XXX: OK?
    [
      :list_header, :list_body, :listnum_body,
      :source_header, :source_body,
      :image_image, :image_dummy,
      :table_header, :table_begin, :tr, :th, :table_end,
      :nofunc_text,
      :compile_ruby, :compile_kw, :compile_href,
      :bibpaper_header, :bibpaper_bibpaper,
      :inline_hd_chap,
    ].each do |m|
      b = Builder.new
      assert_raises(ex) { b.__send__(m) }
    end
  end

  def test_compile_inline
    text = "abc"
    assert_equal [:text, text], @b.compile_inline(text)
  end

  def test_convert_outencoding_1arg
    ReVIEW.book.param = {'outencoding' => "UTF-8"}
    b = Builder.new
    ret = b.convert_outencoding("a")
    assert_equal "a", ret
  end

  def test_convert_outencoding_2arg
    ReVIEW.book.param = {'outencoding' => "UTF-8"}
    b = Builder.new
    ret = b.convert_outencoding("a","b")
    assert_equal(["a","b"], ret)
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

