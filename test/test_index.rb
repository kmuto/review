# encoding: utf-8

require 'test_helper'
require 'review/book'
require 'review/book/index'

class IndexTest < Test::Unit::TestCase
  include ReVIEW
  def test_footnote_index
    fn = Book::FootnoteIndex.parse('//footnote[foo][bar]')
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar', item.content
  end
  def test_footnote_index_with_escape
    fn = Book::FootnoteIndex.parse('//footnote[foo][bar[\]buz]')
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar[]buz', item.content
  end
end

