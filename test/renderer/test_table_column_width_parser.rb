# frozen_string_literal: true

require_relative '../test_helper'
require 'review/renderer/latex_renderer'

class TestTableColumnWidthParser < Test::Unit::TestCase
  def test_default_spec
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.parse(nil, 3)
    assert_equal '|l|l|l|', result[:col_spec]
    assert_equal ['l', 'l', 'l'], result[:cellwidth]
  end

  def test_simple_format
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.parse('10,18,50', 3)
    assert_equal '|p{10mm}|p{18mm}|p{50mm}|', result[:col_spec]
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result[:cellwidth]
  end

  def test_complex_format
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.parse('p{10mm}p{18mm}|p{50mm}', 3)
    assert_equal 'p{10mm}p{18mm}|p{50mm}', result[:col_spec]
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result[:cellwidth]
  end

  def test_complex_format_with_lcr
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.parse('|l|c|r|', 3)
    assert_equal '|l|c|r|', result[:col_spec]
    assert_equal ['l', 'c', 'r'], result[:cellwidth]
  end

  def test_fixed_width_detection
    assert ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.fixed_width?('p{10mm}')
    assert ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.fixed_width?('L{30mm}')
    refute(ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.fixed_width?('l'))
    refute(ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.fixed_width?('c'))
    refute(ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.fixed_width?('r'))
  end

  def test_separate_tsize_simple
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.separate_tsize('lcr')
    assert_equal ['l', 'c', 'r'], result
  end

  def test_separate_tsize_with_braces
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.separate_tsize('p{10mm}p{18mm}p{50mm}')
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result
  end

  def test_separate_tsize_with_pipes
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.separate_tsize('|l|c|r|')
    assert_equal ['l', 'c', 'r'], result
  end

  def test_separate_tsize_mixed
    result = ReVIEW::Renderer::LatexRenderer::TableColumnWidthParser.separate_tsize('p{10mm}p{18mm}|p{50mm}')
    assert_equal ['p{10mm}', 'p{18mm}', 'p{50mm}'], result
  end
end
