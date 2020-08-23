require 'test_helper'
require 'book_test_helper'
require 'review/sec_counter'

class SecCounterTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @book = Book::Base.new
    @io = StringIO.new("= sample\n\n")
    @chapter = Book::Chapter.new(@book, 1, 'foo', '-', @io)
    @part = Book::Part.new(@book, 1, [], 'name')
    I18n.setup
  end

  def test_initialize
    @sec_counter = SecCounter.new(5, @chapter)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-0', @sec_counter.anchor(2))
    assert_equal('1-0-0', @sec_counter.anchor(3))
  end

  def test_anchor1
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(3)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-0', @sec_counter.anchor(2))
    assert_equal('1-0-1', @sec_counter.anchor(3))
  end

  def test_anchor2
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    @sec_counter.inc(4)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-1', @sec_counter.anchor(2))
    assert_equal('1-1-2', @sec_counter.anchor(3))
    assert_equal('1-1-2-1', @sec_counter.anchor(4))
  end

  def test_anchor3
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    @sec_counter.inc(4)
    @sec_counter.inc(3)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-1', @sec_counter.anchor(2))
    assert_equal('1-1-3', @sec_counter.anchor(3))
    assert_equal('1-1-3-0', @sec_counter.anchor(4))
  end

  def test_anchor4
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(2)
    @sec_counter.inc(2)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-3', @sec_counter.anchor(2))
    assert_equal('1-3-2', @sec_counter.anchor(3))
    assert_equal('1-3-2-0', @sec_counter.anchor(4))
  end

  def test_anchor_part1
    @sec_counter = SecCounter.new(5, @part)
    @sec_counter.inc(3)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-0', @sec_counter.anchor(2))
    assert_equal('1-0-1', @sec_counter.anchor(3))
  end

  def test_anchor_part3
    @sec_counter = SecCounter.new(5, @part)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    @sec_counter.inc(4)
    @sec_counter.inc(3)
    assert_equal('1', @sec_counter.anchor(0))
    assert_equal('1', @sec_counter.anchor(1))
    assert_equal('1-1', @sec_counter.anchor(2))
    assert_equal('1-1-3', @sec_counter.anchor(3))
    assert_equal('1-1-3-0', @sec_counter.anchor(4))
  end

  def test_prefix1
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(2)
    assert_equal('1.1　', @sec_counter.prefix(2, 3))
    assert_equal('1.1.0　', @sec_counter.prefix(3, 3))
    assert_equal('1.1.0　', @sec_counter.prefix(3, 5))
  end

  def test_prefix2
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    @sec_counter.inc(4)
    assert_equal('1.1　', @sec_counter.prefix(2, 5))
    assert_equal('1.1　', @sec_counter.prefix(2, 5))
    assert_equal(nil, @sec_counter.prefix(2, 1))
    assert_equal('1.1.2　', @sec_counter.prefix(3, 5))
    assert_equal('1.1.2　', @sec_counter.prefix(3, 3))
    assert_equal(nil, @sec_counter.prefix(3, 2))
  end

  def test_prefix3
    @sec_counter = SecCounter.new(5, @chapter)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    @sec_counter.inc(4)
    @sec_counter.inc(3)
    assert_equal('1.1　', @sec_counter.prefix(2, 5))
    assert_equal('1.1　', @sec_counter.prefix(2, 5))
    assert_equal(nil, @sec_counter.prefix(2, 1))
    assert_equal('1.1.3　', @sec_counter.prefix(3, 5))
    assert_equal('1.1.3　', @sec_counter.prefix(3, 3))
    assert_equal(nil, @sec_counter.prefix(3, 2))
    assert_equal('1.1.3.0　', @sec_counter.prefix(4, 5))
  end

  def test_prefix_part1
    @sec_counter = SecCounter.new(5, @part)
    @sec_counter.inc(2)
    assert_equal('I.1　', @sec_counter.prefix(2, 3))
    assert_equal('I.1.0　', @sec_counter.prefix(3, 3))
    assert_equal('I.1.0　', @sec_counter.prefix(3, 5))
  end

  def test_prefix_part2
    @sec_counter = SecCounter.new(5, @part)
    @sec_counter.inc(2)
    @sec_counter.inc(3)
    @sec_counter.inc(3)
    @sec_counter.inc(4)
    assert_equal('I.1　', @sec_counter.prefix(2, 5))
    assert_equal('I.1　', @sec_counter.prefix(2, 5))
    assert_equal(nil, @sec_counter.prefix(2, 1))
    assert_equal('I.1.2　', @sec_counter.prefix(3, 5))
    assert_equal('I.1.2　', @sec_counter.prefix(3, 3))
    assert_equal(nil, @sec_counter.prefix(3, 2))
  end
end
