require 'test_helper'
require 'review/preprocessor'
require 'stringio'
require 'lineinput'

class PreprocessorStripTest < Test::Unit::TestCase
  include ReVIEW

  def test_gets
    f = StringIO.new '= Header'
    s = Preprocessor::Strip.new(f)
    expect = '= Header'
    actual = s.gets
    assert_equal expect, actual
  end

  def test_ungets
    f = StringIO.new "abc\ndef\n"
    io = Preprocessor::Strip.new(f)
    li = LineInput.new(io)
    line = li.gets
    li.ungets line
    assert_equal "abc\n", li.peek
  end

#  def test_gets_with_comment
#    f = StringIO.new '#@warn(write it later)'
#    s = Preprocessor::Strip.new(f)
#    expect = '#@#' + "\n"
#    actual = s.gets
#    assert_equal expect, actual
#  end
end
