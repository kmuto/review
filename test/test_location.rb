require 'test_helper'
require 'review/location'
require 'review/book'
require 'review/textbuilder'
require 'review/compiler'

class LocationTest < Test::Unit::TestCase
  def setup
    @builder = ReVIEW::TEXTBuilder.new
    dummy_book = ReVIEW::Book::Base.load
    dummy_chapter = ReVIEW::Book::Chapter.new(dummy_book, 1, '-', nil, StringIO.new("a\nb\nc\n"))
    @compiler = ReVIEW::Compiler.new(@builder)
    @location = ReVIEW::Location.new("foo", @compiler)
    @builder.bind(@compiler, dummy_chapter, @location)
    @compiler.setup_parser(dummy_chapter.content)
  end

  def test_lineno
    assert_equal 1, @location.lineno
  end

  def test_string
    assert_equal "foo:1", @location.string
  end

  def test_to_s
    assert_equal "foo:1", "#{@location}"
  end

  def test_to_s_nil
    location = ReVIEW::Location.new("foo", nil)
    assert_equal "foo:nil", "#{location}"
  end
end
