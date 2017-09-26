require 'test_helper'
require 'review/compiler'

class LocationTest < Test::Unit::TestCase
  def setup
  end

  def test_lineno
    f = StringIO.new("a\nb\nc\n")
    location = ReVIEW::Location.new('foo', f)
    assert_equal 0, location.lineno
    f.gets
    assert_equal 1, location.lineno
  end

  def test_string
    location = ReVIEW::Location.new('foo', StringIO.new("a\nb\nc\n"))
    assert_equal 'foo:0', location.string
  end

  def test_to_s
    location = ReVIEW::Location.new('foo', StringIO.new("a\nb\nc\n"))
    assert_equal 'foo:0', location.to_s
  end

  def test_to_s_nil
    location = ReVIEW::Location.new('foo', nil)
    assert_equal 'foo:nil', location.to_s
  end
end
