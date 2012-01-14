require 'test_helper'
require 'review/preprocessor'
require 'stringio'

class PreprocessorStripTest < Test::Unit::TestCase
  include ReVIEW

  def test_gets
    f = StringIO.new '= Header'
    s = Preprocessor::Strip.new(f)
    expect = '= Header'
    actual = s.gets
    assert_equal expect, actual
  end

  def test_gets_with_comment
    f = StringIO.new '#@warn(write it later)'
    s = Preprocessor::Strip.new(f)
    expect = '#@#' + "\n"
    actual = s.gets
    assert_equal expect, actual
  end
end
