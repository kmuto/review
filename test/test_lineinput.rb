require 'test_helper'
require 'review/lineinput'
require 'tempfile'
require 'stringio'

class LineInputTest < Test::Unit::TestCase
  def test_initialize
    io = StringIO.new
    li = LineInput.new(io)
    assert_equal 0, li.lineno
    assert !li.eof?
    assert_equal "#<ReVIEW::LineInput file=#{io.inspect} line=0>", li.inspect
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

    li.while_match(/^[ad]/) do
      # skip
    end
    assert_equal 2, li.lineno
    assert_equal 'ghi', li.gets
  end

  def test_until_match
    io = StringIO.new("abc\ndef\nghi")
    li = LineInput.new(io)

    li.until_match(/^[^a]/) do
      # skip
    end
    assert_equal 1, li.lineno
    assert_equal "def\n", li.gets
  end

  def test_invalid_control_sequence
    0.upto(31) do |n|
      content = n.chr
      io = StringIO.new(content)
      li = ReVIEW::LineInput.new(io)
      if [9, 10, 13].include?(n) # TAB, LF, CR
        assert_equal content, li.gets
      else
        e = assert_raise(ReVIEW::SyntaxError) { li.gets }
        assert_match(/found invalid control/, e.message)
      end
    end
  end
end
