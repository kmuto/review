# -*- coding: utf-8 -*-
require 'book_test_helper'
class ChapterTest < Test::Unit::TestCase
  include BookTestHelper

  def setup

    if "".respond_to?(:encode)
      @utf8_str = "あいうえお"
      @eucjp_str = "あいうえお".encode("EUC-JP")
      @sjis_str = "あいうえお".encode("Shift_JIS")
      @jis_str = "あいうえお".encode("ISO-2022-JP")
    else
      @utf8_str = "\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xe3\x81\x88\xe3\x81\x8a" # "あいうえお"
      @eucjp_str = "\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa"
      @sjis_str = "\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8"
      @jis_str = "\x1b\x24\x42\x24\x22\x24\x24\x24\x26\x24\x28\x24\x2a\x1b\x28\x42"
    end
=begin
    @utf8_str = "\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xe3\x81\x88\xe3\x81\x8a" # "あいうえお"
    @eucjp_str = "\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa"
    @sjis_str = "\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8"
    @jis_str = "\x1b\x24\x42\x24\x22\x24\x24\x24\x26\x24\x28\x24\x2a\x1b\x28\x42"
=end
  end

  def test_initialize
    ch = Book::Chapter.new(:book, :number, :name, '/foo/bar', :io)
    assert_equal :book, ch.book
    assert_equal :number, ch.number
    assert_equal '/foo/bar', ch.path
    assert_equal "#<ReVIEW::Book::Chapter number /foo/bar>", ch.inspect
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

  def test_open
    ch = Book::Chapter.new(nil, nil, nil, __FILE__, :io)
    assert_equal :io, ch.open
    assert_equal [:io], ch.open {|io| [io] }

    ch = Book::Chapter.new(nil, nil, nil, __FILE__)
    assert_equal __FILE__, ch.open.path
    assert_equal [__FILE__], ch.open {|io| [io.path] }
  end

  def test_size
    ch = Book::Chapter.new(nil, nil, nil, __FILE__, :io)
    assert_equal File.size(__FILE__), ch.size

    File.open(__FILE__, 'r') do |i|
      ch = Book::Chapter.new(nil, nil, nil, nil, i)
      assert_raises(TypeError) do # XXX: OK?
        ch.size
      end
    end
  end

  def test_title
    io = StringIO.new
    book = Book::Base.new(nil)
    ch = Book::Chapter.new(book, nil, nil, nil, io)
    assert_equal '', ch.title

    io = StringIO.new("=1\n=2\n")
    ch = Book::Chapter.new(book, nil, nil, nil, io)
    assert_equal '1', ch.title


    [
      ['EUC', @eucjp_str],
      ['SJIS', @sjis_str],
#      ['JIS', @jis_str],
      ['XYZ', @eucjp_str],
    ].each do |enc, instr|
      io = StringIO.new("= #{instr}\n")
      ch = Book::Chapter.new(book, nil, nil, nil, io)
      book.config['inencoding'] = enc
      assert_equal @utf8_str, ch.title
      assert_equal @utf8_str, ch.instance_eval { @title }
    end
  end

  def test_content
    [
      ['EUC', @eucjp_str],
      ['SJIS', @sjis_str],
      ['JIS', @jis_str],
      ['XYZ', @eucjp_str],
    ].each do |enc, instr|
      tf = Tempfile.new('chapter_test')
      book = Book::Base.new(nil)
      begin
        tf.print instr
        tf.close

        ch = Book::Chapter.new(book, nil, nil, tf.path)
        book.config['inencoding'] = enc
        assert_equal @utf8_str, ch.content
        assert_equal @utf8_str, ch.instance_eval { @content }
      ensure
        tf.close(true)
      end

      tf1 = Tempfile.new('chapter_test1')
      tf2 = Tempfile.new('chapter_test2')
      begin
        tf1.puts instr
        tf1.puts instr
        tf1.close
        tf2.puts instr
        tf1.close

        ch = Book::Chapter.new(book, nil, nil, tf1.path, tf2)
        book.config['inencoding'] = enc
        assert_equal "#{@utf8_str}\n#{@utf8_str}\n", ch.content # XXX: OK?
      ensure
        tf1.close(true)
        tf2.close(true)
      end
    end
  end

  def test_lines
    lines = ["1\n", "2\n", "3"]
    tf = Tempfile.new('chapter_test')
    tf.print lines.join('')
    tf.close

    book = Book::Base.new(nil)
    ch = Book::Chapter.new(book, nil, nil, tf.path)
    assert_equal lines, ch.lines

    lines = ["1\n", "2\n", "3"]
    tf1 = Tempfile.new('chapter_test1')
    tf1.print lines.join('')
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.puts lines.join('')
    tf2.puts lines.join('')
    tf2.close

    ch = Book::Chapter.new(book, nil, nil, tf1.path, tf2.path)
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

    book = Book::Base.new(nil)
    ch = Book::Chapter.new(book, nil, nil, tf1.path)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes

    book = Book::Base.new(nil)
    ch = Book::Chapter.new(book, nil, nil, tf1.path, tf2)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes # XXX: OK?
  end

  def test_on_CHAPS?
    mktmpbookdir 'CHAPS' => "chapter1.re\nchapter2.re",
                 'chapter1.re' => '12345', 'preface.re' => 'abcde' do |dir, book, files|
      ch1 = Book::Chapter.new(book, 1, 'chapter1', files['chapter1.re'])
      pre = Book::Chapter.new(book, nil, 'preface', files['preface.re'])

      assert ch1.on_CHAPS?
      assert !pre.on_CHAPS?

      ch2_path = File.join(dir, 'chapter2.er')
      File.open(ch2_path, 'w') {}
      ch2 = Book::Chapter.new(book, 2, 'chapter2', ch2_path)

      ch3_path = File.join(dir, 'chapter3.er')
      File.open(ch3_path, 'w') {}
      ch3 = Book::Chapter.new(book, 3, 'chapter3', ch3_path)

      assert ch2.on_CHAPS?
      assert !ch3.on_CHAPS?
    end
  end

  def test_list_index
    do_test_index(<<E, Book::ListIndex, :list_index, :list)
//list
//listnum [abc]
//list [def]
//table [def]
//table [others]
E
  end

  def test_table_index
    do_test_index(<<E, Book::TableIndex, :table_index, :table)
//table
//table [abc]
//table [def]
//list [def]
//list [others]
E
  end

  def test_footnote_index
    content = <<E
//footnote
//footnote [abc][text...]
//footnote [def][text...]
//footnote [xyz]
//list [def]
//list [others]
E
    do_test_index(content, Book::FootnoteIndex, :footnote_index, :footnote) do |ch|
      assert_raises ReVIEW::KeyError do
        ch.footnote('xyz')
      end
    end
  end

  def test_bibpaper
    do_test_index(<<E, Book::BibpaperIndex, :bibpaper_index, :bibpaper, :filename => 'bib.re')
//bibpaper
//bibpaper [abc][text...]
//bibpaper [def][text...]
//bibpaper [xyz]
//list [def]
//list [others]
E
    assert_raises FileNotFound do
      do_test_index('', Book::BibpaperIndex, :bibpaper_index, :bibpaper, :filename => 'bib')
    end
  end

  def test_headline_index
    do_test_index(<<E, Book::HeadlineIndex, :headline_index, :headline, :propagate => false)
==
== abc
== def
=== def
//table others
E
  end


  def test_headline_index_nullsection
    do_test_index(<<E, Book::HeadlineIndex, :headline_index, :headline, :propagate => false)
== abc
==== dummy
== def
E
  end


  def test_column_index
    book = Book::Base.new(nil)
    book.config["inencoding"] = "utf-8"
    do_test_index(<<E, Book::ColumnIndex, :column_index, :column, :propagate => false)
= dummy1
===[column]{abc} aaaa
= dummy2
===[column] def
== dummy3
E
  end

  def test_image
    do_test_index(<<E, Book::ImageIndex, :image_index, :image)
//image
//image [abc]
//image [def]
//list [def]
//list [others]
E

    do_test_index(<<E, Book::NumberlessImageIndex, :numberless_image_index, :image, :propagate => false)
//numberlessimage
//numberlessimage [abc]
//numberlessimage [def]
//list [def]
//list [others]
E

    do_test_index(<<E, Book::ImageIndex, :image_index, :image)
//image
//numberlessimage [abc]
//image [def]
//list [def]
//list [others]
E

    do_test_index(<<E, Book::NumberlessImageIndex, :numberless_image_index, :image, :propagate => false)
//image
//numberlessimage [abc]
//image [def]
//list [def]
//list [others]
E
  end

  def do_test_index(content, klass, list_method, ref_method, opts = {})
    Dir.mktmpdir do |dir|
      path = File.join(dir, opts[:filename] || 'chapter.re')

      book = Book::Base.new(dir)

      ch = nil
      File.open(path, 'w') do |o|
        o.print content
        ch = Book::Chapter.new(book, 1, 'chapter', o.path)
      end

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
