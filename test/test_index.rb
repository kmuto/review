# encoding: utf-8

require 'test_helper'
require 'review/book'
require 'review/book/index'

class IndexTest < Test::Unit::TestCase
  include ReVIEW
  def test_footnote_index
    fn = Book::FootnoteIndex.parse(['//footnote[foo][bar]'])
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar', item.content
  end
  def test_footnote_index_with_escape
    fn = Book::FootnoteIndex.parse(['//footnote[foo][bar[\]buz]'])
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar[]buz', item.content
  end
  def test_footnote_index_with_escape2
    fn = Book::FootnoteIndex.parse(['//footnote[foo][bar\\a\\$buz]'])
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar\\a\\$buz', item.content
  end

  def test_HeadelineIndex
    src = <<-EOB
= chap1
== sec1-1
== sec1-2
=== sec1-2-1
===[column] column1
===[/column]
=== sec1-2-2
== sec1-3
==== sec1-3-0-1
    EOB
    chap = Book::Chapter.new(nil, 1, '-', nil) # dummy
    index = Book::HeadlineIndex.parse(src, chap)
    assert_equal [2,2], index['sec1-2|sec1-2-2'].number
    assert_equal "1.2.2", index.number('sec1-2|sec1-2-2')
  end
end

