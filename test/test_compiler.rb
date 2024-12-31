# frozen_string_literal: true

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/latexbuilder'

class CompilerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = LATEXBuilder.new
    @c = Compiler.new(@builder)
  end

  def test_parse_args
    args = @c.__send__(:parse_args, '[foo][bar]')
    assert_equal ['foo', 'bar'], args
  end

  def test_parse_args_with_brace1
    args = @c.__send__(:parse_args, '[fo[\\][\\]o][bar]')
    assert_equal ['fo[][]o', 'bar'], args
  end

  def test_parse_args_with_brace2
    args = @c.__send__(:parse_args, '[f\\]o\\]o][bar]')
    assert_equal ['f]o]o', 'bar'], args
  end

  def test_parse_args_with_backslash
    args = @c.__send__(:parse_args, '[foo][bar\\buz]')
    assert_equal ['foo', 'bar\\buz'], args
  end

  def test_parse_args_with_backslash2
    args = @c.__send__(:parse_args, '[foo][bar\\#\\[\\!]')
    assert_equal ['foo', 'bar\\#\\[\\!'], args
  end

  def test_parse_args_with_backslash3
    args = @c.__send__(:parse_args, '[foo][bar\\\\buz]')
    assert_equal ['foo', 'bar\\buz'], args
  end

  def test_replace_fence
    source_str = <<-'EOB'
@<m>${}\}|$, @<m>|{}\}\$|, @<m>|\{\a\}|, @<tt>|}|, @<tt>|\|, @<tt>|\\|, @<tt>|\\\|
    EOB
    expected = "@<m>{\x03\x04\x02\x04|}, @<m>{\x03\x04\x02\x04\x02$}, @<m>{\x02\x03\x02a\x02\x04}, @<tt>{\x04}, @<tt>{\x02}, @<tt>{\x02\x02}, @<tt>{\x02\x02\x02}\n"
    actual = @c.__send__(:replace_fence, source_str)
    assert_equal expected, actual
  end
end
