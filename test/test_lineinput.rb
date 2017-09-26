require 'test_helper'
require 'lineinput'
require 'tempfile'
require 'stringio'

class LineInputTest < Test::Unit::TestCase
  def test_initialize
    io = StringIO.new
    li = LineInput.new(io)
    assert_equal 0, li.lineno
    assert !li.eof?
    assert_equal "#<LineInput file=#{io.inspect} line=0>", li.inspect
  end

  def test_gets
    content = "abc\ndef\r\nghi\rjkl"
    do_test_gets(StringIO.new(content))
    Tempfile.open('lineinput_test') do |io|
      io.print content
      io.rewind
      do_test_gets(io)
    end
  end

  def do_test_gets(io)
    li = LineInput.new(io)

    assert_equal "abc\n", li.gets
    assert_equal "def\r\n", li.gets
    assert_equal "ghi\rjkl", li.gets
    assert_equal 3, li.lineno
    assert !li.eof?

    assert_equal nil, li.gets
    assert_equal 4, li.lineno # XXX: OK?
    assert li.eof?

    assert_equal nil, li.gets
    assert_equal 4, li.lineno
    assert li.eof?
  end

  def test_ungets
    io = StringIO.new('abc')
    li = LineInput.new(io)

    line = li.gets
    assert_equal line, li.ungets(line)
    assert_equal 0, li.lineno
    assert_equal line, li.gets

    li.ungets('xyz')
    assert_equal 0, li.lineno
    li.ungets('xyz')
    assert_equal(-1, li.lineno) # XXX: OK?
  end

  def test_peek
    li = LineInput.new(StringIO.new)
    assert_equal nil, li.peek

    li = LineInput.new(StringIO.new('abc'))
    assert_equal 'abc', li.peek
  end

  def test_next?
    li = LineInput.new(StringIO.new)
    assert !li.next?

    li = LineInput.new(StringIO.new('abc'))
    assert li.next?
  end

  def test_gets_if
    io = StringIO.new
    li = LineInput.new(io)
    assert_equal nil, li.gets_if(//)

    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    assert_equal "abc\n", li.gets_if(//)
    assert_equal nil, li.gets_if(/^X/)
    assert_equal nil, li.gets_if(/^g/)
    assert_equal "def\n", li.gets_if(/^d/)
  end

  def test_gets_unless
    io = StringIO.new
    li = LineInput.new(io)
    assert_equal nil, li.gets_unless(//)

    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    assert_equal nil, li.gets_unless(//)
    assert_equal "abc\n", li.gets_unless(/^X/)
    assert_equal nil, li.gets_unless(/^d/)
  end

  def test_each
    content = "abc\ndef\nghi"
    io = StringIO.new(content)
    li = LineInput.new(io)

    data = ''
    li.each { |l| data << l }
    assert_equal content, data
  end

  def test_while_match
    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    li.while_match(/^[ad]/) {}
    assert_equal 2, li.lineno
    assert_equal 'ghi', li.gets
  end

  def test_getlines_while
    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    buf = li.getlines_while(/^[ad]/)
    assert_equal ["abc\n", "def\n"], buf
    assert_equal 2, li.lineno
    assert_equal 'ghi', li.gets
  end

  def test_until_match
    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    li.until_match(/^[^a]/) {}
    assert_equal 1, li.lineno
    assert_equal "def\n", li.gets
  end

  def test_getlines_until
    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    buf = li.getlines_until(/^[^a]/)
    assert_equal ["abc\n"], buf
    assert_equal 1, li.lineno
    assert_equal "def\n", li.gets
  end

  def test_until_terminator
    io = StringIO.new("abc\n//}\ndef\nghi\n//}\njkl\nmno")
    li = LineInput.new(io)

    data = ''
    li.until_terminator(%r<\A//\}>) { |l| data << l }
    assert_equal "abc\n", data
    assert_equal 2, li.lineno

    data = ''
    li.until_terminator(%r<\A//\}>) { |l| data << l }
    assert_equal "def\nghi\n", data
    assert_equal 5, li.lineno

    data = ''
    li.until_terminator(%r<\A//\}>) { |l| data << l }
    assert_equal "jkl\nmno", data
    assert_equal 8, li.lineno
  end

  def test_until_terminator2
    io = StringIO.new("abc\ndef\n//}\nghi\n//}")
    li = LineInput.new(io)

    data = li.getblock(%r<\A//\}>)
    assert_equal ["abc\n", "def\n"], data
    assert_equal 3, li.lineno
  end
end
