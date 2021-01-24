require 'test_helper'
require 'review/tocprinter'
require 'unicode/eaw'

class TOCPrinterTest < Test::Unit::TestCase
  def setup
    @toc_printer = ReVIEW::TOCPrinter.new
  end

  def teardown
  end

  def test_calc_linesize
    @toc_printer.calc_char_width = nil
    size = @toc_printer.calc_linesize('あ いうえおABCD')
    assert_equal 10, size
    size = @toc_printer.calc_linesize("あ い\nうえ\nおAB\nCD\n")
    assert_equal 14, size
  end

  def test_calc_linesize_with_char_width
    @toc_printer.calc_char_width = true
    size = @toc_printer.calc_linesize('あ いうえおABCD')
    assert_equal 7.5, size
    size = @toc_printer.calc_linesize("あ い\nうえ\nおAB\nCD\n")
    assert_equal 9.5, size
  end
end
