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

  def test_execute_syntax_book_detail
    Dir.chdir('./samples/syntax-book') do
      stdout = $stdout
      tmp_io = StringIO.new
      $stdout = tmp_io
      begin
        @toc_printer.execute('-d')
        tmp_io.rewind
        result = tmp_io.read
        path = File.join(assets_dir, 'syntax_book_index_detail.txt')
        expected = File.read(path)
        assert_equal expected, result
      ensure
        $stdout = stdout
      end
    end
  end
end
