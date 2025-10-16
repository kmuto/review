# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative '../test_helper'
require 'review/renderer/base'
require 'review/ast'
require 'review/book'
require 'review/book/chapter'

class TestRendererBase < Test::Unit::TestCase
  include ReVIEW

  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @book.config = @config
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    @chapter.generate_indexes
    @book.generate_indexes

    @renderer = Renderer::Base.new(@chapter)
  end

  # Tests for parse_metric method
  def test_parse_metric_with_prefix
    # Test parsing metric with builder prefix
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_parse_metric_without_prefix
    # Test parsing metric without prefix
    result = @renderer.send(:parse_metric, 'latex', 'width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_parse_metric_multiple_values
    # Test parsing metric with multiple comma-separated values
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm,latex::height=60mm')
    assert_equal 'width=80mm,height=60mm', result
  end

  def test_parse_metric_mixed_prefix_and_no_prefix
    # Test parsing metric with mixed prefix and non-prefix values
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm,height=60mm')
    assert_equal 'width=80mm,height=60mm', result
  end

  def test_parse_metric_wrong_prefix
    # Test parsing metric with wrong builder prefix (should be filtered out)
    result = @renderer.send(:parse_metric, 'latex', 'html::width=80mm')
    assert_equal '', result
  end

  def test_parse_metric_multiple_builder_prefixes
    # Test parsing metric with multiple builder prefixes
    result = @renderer.send(:parse_metric, 'latex', 'html::width=100px,latex::width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_parse_metric_multiple_values_different_builders
    # Test parsing metric with multiple values for different builders
    result = @renderer.send(:parse_metric, 'html', 'html::width=100px,latex::width=80mm,html::height=60px')
    assert_equal 'width=100px,height=60px', result
  end

  def test_parse_metric_nil
    # Test parsing nil metric
    result = @renderer.send(:parse_metric, 'latex', nil)
    assert_equal '', result
  end

  def test_parse_metric_empty_string
    # Test parsing empty string metric
    result = @renderer.send(:parse_metric, 'latex', '')
    assert_equal '', result
  end

  def test_parse_metric_whitespace_handling
    # Test parsing metric with spaces around commas
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm, latex::height=60mm')
    assert_equal 'width=80mm,height=60mm', result
  end

  def test_parse_metric_complex_values
    # Test parsing metric with complex values
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=0.8\\textwidth,latex::height=!,latex::keepaspectratio')
    assert_equal 'width=0.8\\textwidth,height=!,keepaspectratio', result
  end

  # Tests for handle_metric method (default implementation does nothing)
  def test_handle_metric_default
    # Test that default handle_metric returns input unchanged
    result = @renderer.send(:handle_metric, 'width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_handle_metric_with_special_chars
    # Test that default handle_metric handles special characters
    result = @renderer.send(:handle_metric, 'width=0.8\\textwidth')
    assert_equal 'width=0.8\\textwidth', result
  end

  # Tests for result_metric method
  def test_result_metric_single_value
    # Test combining single metric value
    result = @renderer.send(:result_metric, ['width=80mm'])
    assert_equal 'width=80mm', result
  end

  def test_result_metric_multiple_values
    # Test combining multiple metric values
    result = @renderer.send(:result_metric, ['width=80mm', 'height=60mm', 'scale=0.5'])
    assert_equal 'width=80mm,height=60mm,scale=0.5', result
  end

  def test_result_metric_empty_array
    # Test combining empty array
    result = @renderer.send(:result_metric, [])
    assert_equal '', result
  end

  # Integration test
  def test_parse_metric_integration
    # Test full flow with mixed prefixes and values
    metric_string = 'html::width=100%,latex::width=80mm,scale=0.5,latex::height=60mm,html::height=80%'
    result = @renderer.send(:parse_metric, 'latex', metric_string)
    assert_equal 'width=80mm,scale=0.5,height=60mm', result
  end
end
