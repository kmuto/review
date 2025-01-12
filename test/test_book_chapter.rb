# frozen_string_literal: true

require 'book_test_helper'

class ChapterTest < Test::Unit::TestCase
  include BookTestHelper

  def setup
    I18n.setup
  end

  def test_initialize
    ch = Book::Chapter.new(:book, :number, :name, '/foo/bar', :io)
    assert_equal :book, ch.book
    assert_equal :number, ch.number
    assert_equal '/foo/bar', ch.path
    assert_equal '#<ReVIEW::Book::Chapter number /foo/bar>', ch.inspect
  end

  def test_dirname_and_basename
    ch = Book::Chapter.new(nil, nil, nil, nil, nil)
    assert_equal nil, ch.dirname
    assert_equal nil, ch.basename

    ch = Book::Chapter.new(nil, nil, nil, '/foo/bar', nil)
    assert_equal '/foo', ch.dirname
    assert_equal 'bar', ch.basename

    ch = Book::Chapter.new(nil, nil, nil, 'bar', nil)
    assert_equal '.', ch.dirname
    assert_equal 'bar', ch.basename
  end

  def test_name
    ch = Book::Chapter.new(nil, nil, 'foo', nil)
    assert_equal 'foo', ch.name

    ch = Book::Chapter.new(nil, nil, 'foo.bar', nil)
    assert_equal 'foo', ch.name

    # ch = Book::Chapter.new(nil, nil, nil, nil)
    # assert_raises(TypeError) { ch.name } # XXX: OK?
  end

  def test_size
    ch = Book::Chapter.new(nil, nil, nil, __FILE__, :io)
    filesize = File.read(__FILE__, mode: 'rt:BOM|utf-8').size
    assert_equal filesize, ch.size

    File.open(__FILE__, 'r') do |i|
      ch = Book::Chapter.new(nil, nil, nil, nil, i)
      filesize = File.read(__FILE__, mode: 'rt:BOM|utf-8').size
      assert_equal filesize, ch.size
    end
  end

  def test_title
    io = StringIO.new
    book = Book::Base.new
    ch = Book::Chapter.new(book, nil, nil, nil, io)
    assert_equal '', ch.title

    io = StringIO.new("=1\n=2\n")
    ch = Book::Chapter.new(book, nil, nil, nil, io)
    assert_equal '1', ch.title
  end

  def test_lines
    lines = ["1\n", "2\n", '3']
    tf = Tempfile.new('chapter_test')
    tf.print lines.join
    tf.close

    book = Book::Base.new
    ch = Book::Chapter.new(book, nil, nil, tf.path)
    ch.generate_indexes
    assert_equal lines, ch.lines

    lines = ["1\n", "2\n", '3']
    tf1 = Tempfile.new('chapter_test1')
    tf1.print lines.join
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.puts lines.join
    tf2.puts lines.join
    tf2.close

    ch = Book::Chapter.new(book, nil, nil, tf1.path, tf2.path)
    ch.generate_indexes
    assert_equal lines, ch.lines # XXX: OK?
  end

  def test_volume
    content = "abc\ndef"
    tf1 = Tempfile.new('chapter_test1')
    tf1.print content
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.print content
    tf2.print content
    tf2.close

    book = Book::Base.new
    ch = Book::Chapter.new(book, nil, nil, tf1.path)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes

    book = Book::Base.new
    ch = Book::Chapter.new(book, nil, nil, tf1.path, tf2)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes # XXX: OK?
  end

  def test_on_chaps?
    mktmpbookdir('CHAPS' => "chapter1.re\nchapter2.re",
                 'chapter1.re' => '12345', 'preface.re' => 'abcde') do |dir, book, files|
      ch1 = Book::Chapter.new(book, 1, 'chapter1', files['chapter1.re'])
      pre = Book::Chapter.new(book, nil, 'preface', files['preface.re'])

      assert ch1.on_chaps?
      assert !pre.on_chaps?

      ch2_path = File.join(dir, 'chapter2.re')
      FileUtils.touch(ch2_path)
      ch2 = Book::Chapter.new(book, 2, 'chapter2', ch2_path)

      ch3_path = File.join(dir, 'chapter3.re')
      FileUtils.touch(ch3_path)
      ch3 = Book::Chapter.new(book, 3, 'chapter3', ch3_path)

      assert ch2.on_chaps?
      assert !ch3.on_chaps?
    end
  end

  def test_invalid_encoding
    mktmpbookdir('CHAPS' => 'chapter1.re',
                 'chapter1.re' => "= 日本語UTF-8\n") do |_dir, book, files|
      assert Book::Chapter.new(book, 1, 'chapter1', files['chapter1.re'])
    end

    # UTF-16LE UTF-16BE UTF-32LE UTF-32BE cause error on Windows
    %w[CP932 SHIFT_JIS EUC-JP].each do |enc|
      mktmpbookdir('CHAPS' => 'chapter1.re',
                   'chapter1.re' => "= 日本語UTF-8\n".encode(enc)) do |_dir, book, files|
        e = assert_raises(ReVIEW::CompileError) { Book::Chapter.new(book, 1, 'chapter1', files['chapter1.re']) }
        assert_equal 'chapter1: invalid byte sequence in UTF-8', e.message
      end
    end
  end

  def test_list_index
    do_test_index(<<E, Book::ListIndex, :list_index, :list)
//listnum[abc][abc-listnum]{
//}
//list[def][def-list]{
//}
//table[def]{
//}
//table[others]{
//}
E
  end

  def test_table_index
    do_test_index(<<E, Book::TableIndex, :table_index, :table)
//table[abc]{
//}
//table[def]{
//}
//list[def][def-list]{
//}
//list[others][other-list]{
//}
E
  end

  def test_footnote_index
    content = <<E
@<fn>{abc}@<fn>{def}@<fn>{xyz}
//footnote[abc][textabc...]
//footnote[def][textdef...]
//footnote[xyz][textxyz...]
//list[def][def-list]{
//}
//list[others][others-list]{
//}
E
    do_test_index(content, Book::FootnoteIndex, :footnote_index, :footnote) do |ch|
      assert_raises ReVIEW::KeyError do
        ch.footnote('xyz2')
      end
    end
  end

  def test_endnote_index
    content = <<E
@<fn>{abc}@<fn>{def}@<fn>{xyz}@<endnote>{abc}@<endnote>{def}@<endnote>{xyz}
//footnote[abc][textabc...]
//footnote[def][textdef...]
//footnote[xyz][textxyz...]
//endnote[abc][textabc...]
//endnote[def][textdef...]
//endnote[xyz][textxyz...]
//list[def][def-list]{
//}
//list[others][others-list]{
//}
E
    do_test_index(content, Book::EndnoteIndex, :endnote_index, :endnote) do |ch|
      assert_raises ReVIEW::KeyError do
        ch.endnote('xyz2')
      end
    end
  end

  def test_bibpaper
    do_test_index(<<E, Book::BibpaperIndex, :bibpaper_index, :bibpaper, filename: 'bib.re')
//bibpaper[abc][text...]
//bibpaper[def][text...]
//bibpaper[xyz][text...]
E
    assert_raises FileNotFound do
      do_test_index('', Book::BibpaperIndex, :bibpaper_index, :bibpaper, filename: 'bib')
    end
  end

  def test_headline_index
    do_test_index(<<E, Book::HeadlineIndex, :headline_index, :headline, propagate: false)
== x
== abc
== def
=== def
//table[others]{
//}
E
  end

  def test_headline_index_nullsection
    do_test_index(<<E, Book::HeadlineIndex, :headline_index, :headline, propagate: false)
== abc
==== dummy
== def
E
  end

  def test_column_index
    do_test_index(<<E, Book::ColumnIndex, :column_index, :column, propagate: false)
= dummy1
===[column]{abc} aaaa
= dummy2
===[column] def
== dummy3
E
  end

  def test_image
    do_test_index(<<E, Book::ImageIndex, :image_index, :image)
//image[abc][abc-image]{
//}
//image[def][abc-image]{
//}
//list[def][def-list]{
//}
//list[others][others-list]{
//}
E

    do_test_index(<<E, Book::NumberlessImageIndex, :numberless_image_index, :image, propagate: false)
//numberlessimage[abc]{
//}
//numberlessimage[def]{
//}
//list[def][def-list]{
//}
//list[others][others-list]{
//}
E

    do_test_index(<<E, Book::ImageIndex, :image_index, :image)
//numberlessimage[abc]{
//}
//image[def][def-image]{
//}
//list[def][def-list]{
//}
//list[others][others-list]{
//}
E

    do_test_index(<<E, Book::NumberlessImageIndex, :numberless_image_index, :image, propagate: false)
//numberlessimage[abc]{
//}
//image[def][def-image]{
//}
//list[def][def-list]{
//}
//list[others][others-list]{
//}
E
  end

  def do_test_index(content, _klass, _list_method, ref_method, opts = {})
    Dir.mktmpdir do |dir|
      path = File.join(dir, opts[:filename] || 'chapter.re')

      File.open(path, 'w') do |o|
        o.print content
      end

      book = Book::Base.new(dir)

      ch = Book::Chapter.new(book, 1, 'chapter', path)
      book.generate_indexes
      ch.generate_indexes
      assert ch.__send__(ref_method, 'abc')
      assert ch.__send__(ref_method, 'def')
      assert_raises ReVIEW::KeyError do
        ch.__send__(ref_method, nil)
      end
      assert_raises ReVIEW::KeyError do
        ch.__send__(ref_method, 'others')
      end
      assert_raises ReVIEW::KeyError do
        ch.__send__(ref_method, 'not exist id')
      end

      yield(ch) if block_given?
    end
  end
end
