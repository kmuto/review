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
      b.print ""
    end
    assert_raises(NoMethodError) do # XXX: OK?
      b.puts ""
    end

    if "".respond_to?(:encode)
      utf8_str = "あいうえお"
      eucjp_str = "あいうえお".encode("EUC-JP")
      sjis_str = "あいうえお".encode("Shift_JIS")
      jis_str = "あいうえお".encode("ISO-2022-JP")
    else
      utf8_str = "\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xe3\x81\x88\xe3\x81\x8a" # "あいうえお"
      eucjp_str = "\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa"
      sjis_str = "\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8"
      jis_str = "\x1b\x24\x42\x24\x22\x24\x24\x24\x26\x24\x28\x24\x2a\x1b\x28\x42"
    end

    [
      ['EUC', eucjp_str],
      ['SJIS', sjis_str],
#      ['JIS', jis_str],
#      ['jis', jis_str],
#      ['jIs', jis_str],
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
        chapter = ReVIEW::Book::Chapter.new(ReVIEW::Book::Base.load, nil, '-', nil)
        b.bind(nil, chapter, nil)
        chapter.book.config = params
        b.__send__(m, instr)
        if "".respond_to?(:encode)
          assert_equal expstr.encode("UTF-8"), b.result
        else
          assert_equal expstr, b.result
        end
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

  def test_inline_ruby
    def @b.compile_ruby(base,ruby)
      [base,ruby]
    end
    str = @b.inline_ruby("foo,bar")
    assert_equal str, ["foo","bar"]
    str = @b.inline_ruby("foo\\,\\,,\\,bar,buz")
    assert_equal str, ["foo,,",",bar,buz"]
  end

  def test_compile_inline_backslash
    text = "abc\\d\\#a"
    assert_equal [:text, text], @b.compile_inline(text)
  end

  def test_convert_outencoding
    book = ReVIEW::Book::Base.new(nil)
    book.config = {'outencoding' => "EUC"}
    b = Builder.new
    ret = b.convert_outencoding("a", book.config["outencoding"])
    assert_equal "a", ret
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

