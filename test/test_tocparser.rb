require 'test_helper'
require 'review/tocparser'

class TOCParserTest < Test::Unit::TestCase
  include ReVIEW

  def test_tocparser_parse_null
    dummy_book = ReVIEW::Book::Base.load
    chap = ReVIEW::Book::Chapter.new(dummy_book, 1, '-', nil, StringIO.new)
    ret = TOCParser.parse(chap)
    assert_equal [], ret
  end

  def test_tocparser_parse
    dummy_book = ReVIEW::Book::Base.load
    io = StringIO.new("= test\n\naaa\n//image[foo][bar]{\n//}\n\n== test2\n\n=== test3\n\n==test21\n\n=test11\n")
    chap = ReVIEW::Book::Chapter.new(dummy_book, 1, 'foo', 'bar/foo.re', io)
    ret = TOCParser.parse(chap)
    assert_equal 2, ret.size ## XXX how to count chapters including multiple L1 headlines ??
    chap_node = ret[0]
    assert_equal ReVIEW::TOCParser::Chapter, chap_node.class
    assert_equal 'foo', chap_node.chapter_id
    assert_equal 1, chap_node.number
  end
end
