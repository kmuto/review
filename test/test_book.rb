require 'test_helper'
require 'review/book'
require 'stringio'
require 'tempfile'

include ReVIEW

class BookTest < Test::Unit::TestCase
  def test_s_load_default
    Dir.chdir(File.dirname(__FILE__)) do
      assert Book.load_default
    end
  end
end

class ChapterTest < Test::Unit::TestCase
  def setup
    @utf8_str = "\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xe3\x81\x88\xe3\x81\x8a" # "あいうえお"
    @eucjp_str = "\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa"
    @sjis_str = "\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8"
    @jis_str = "\x1b\x24\x42\x24\x22\x24\x24\x24\x26\x24\x28\x24\x2a\x1b\x28\x42"
  end

  def test_s_intern_pathes
    assert nil
  end

  def test_s_for_stdin
    assert Chapter.for_stdin
  end

  def test_s_for_path
    assert Chapter.for_path(1, __FILE__)
  end

  def test_initialize
    ch = Chapter.new(:book, :number, :name, '/foo/bar', :io)
    assert_equal :book, ch.env
    assert_equal :book, ch.book
    assert_equal :number, ch.number
    assert_equal '/foo/bar', ch.path
    assert_equal "#<ReVIEW::Chapter number /foo/bar>", ch.inspect
  end

  def test_dirname_and_basename
    ch = Chapter.new(nil, nil, nil, nil, nil)
    assert_equal nil, ch.dirname
    assert_equal nil, ch.basename

    ch = Chapter.new(nil, nil, nil, '/foo/bar', nil)
    assert_equal '/foo', ch.dirname
    assert_equal 'bar', ch.basename

    ch = Chapter.new(nil, nil, nil, 'bar', nil)
    assert_equal '.', ch.dirname
    assert_equal 'bar', ch.basename
  end

  def test_name
    ch = Chapter.new(nil, nil, 'foo', nil)
    assert_equal 'foo', ch.name

    ch = Chapter.new(nil, nil, 'foo.bar', nil)
    assert_equal 'foo', ch.name

    ch = Chapter.new(nil, nil, nil, nil)
    assert_raises(TypeError) { ch.name } # XXX: OK?
  end

  def test_setParameter
    ch = Chapter.new(nil, nil, nil, nil, nil)
    ch.setParameter(:test)
    assert_equal :test, ch.instance_eval {@param}
  end

  def test_open
    ch = Chapter.new(nil, nil, nil, __FILE__, :io)
    assert_equal :io, ch.open
    assert_equal [:io], ch.open {|io| [io] }

    ch = Chapter.new(nil, nil, nil, __FILE__)
    assert_equal __FILE__, ch.open.path
    assert_equal [__FILE__], ch.open {|io| [io.path] }
  end

  def test_size
    ch = Chapter.new(nil, nil, nil, __FILE__, :io)
    assert_equal File.size(__FILE__), ch.size

    File.open(__FILE__, 'r') do |i|
      ch = Chapter.new(nil, nil, nil, nil, i)
      assert_raises(TypeError) do # XXX: OK?
        ch.size
      end
    end
  end

  def test_title
    io = StringIO.new
    ch = Chapter.new(nil, nil, nil, nil, io)
    ch.setParameter({})
    assert_equal '', ch.title

    io = StringIO.new("=1\n=2\n")
    ch = Chapter.new(nil, nil, nil, nil, io)
    ch.setParameter({})
    assert_equal '1', ch.title


    [
      ['EUC', @eucjp_str],
      ['SJIS', @sjis_str],
      ['JIS', @jis_str],
      ['XYZ', @eucjp_str],
    ].each do |enc, instr|
      io = StringIO.new("= #{instr}\n")
      ch = Chapter.new(nil, nil, nil, nil, io)
      ch.setParameter({'inencoding' => enc})
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
      begin
        tf.print instr
        tf.close

        ch = Chapter.new(nil, nil, nil, tf.path)
        ch.setParameter({'inencoding' => enc})
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

        ch = Chapter.new(nil, nil, nil, tf1.path, tf2)
        ch.setParameter({'inencoding' => enc})
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

    ch = Chapter.new(nil, nil, nil, tf.path)
    ch.setParameter({})
    assert_equal lines, ch.lines

    lines = ["1\n", "2\n", "3"]
    tf1 = Tempfile.new('chapter_test1')
    tf1.print lines.join('')
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.puts lines.join('')
    tf2.puts lines.join('')
    tf2.close

    ch = Chapter.new(nil, nil, nil, tf1.path, tf2.path)
    ch.setParameter({})
    assert_equal lines, ch.lines # XXX: OK?
  end

  def test_valume
    content = "abc\ndef"
    tf1 = Tempfile.new('chapter_test1')
    tf1.print content
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.print content
    tf2.print content
    tf2.close

    ch = Chapter.new(nil, nil, nil, tf1.path)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes

    ch = Chapter.new(nil, nil, nil, tf1.path, tf2)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes # XXX: OK?
  end
end
