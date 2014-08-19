require 'book_test_helper'

class ParametersTest < Test::Unit::TestCase
  include BookTestHelper

  def test_s_default
    assert Book::Parameters.new
  end

  # def test_s_load
  #   Tempfile.open('parameters_test') do |io|
  #     io.puts 'CHAPS_FILE = "x_CHAPS"'
  #     io.puts 'PAPER = "B5"' # XXX: avoid erros of the last line of Parameters.get_page_metric
  #     io.close
  #
  #     params = Book::Parameters.load(io.path)
  #     assert_equal '/x_CHAPS', params.chapter_file # XXX: OK? (leading / and uninitialized @basedir)
  #     assert_equal '/PART', params.part_file
  #   end
  # end

   def test_param_path
     params = Book::Parameters.new
     assert_equal '/CHAPS', params.chapter_file # XXX: OK? (leading / and uninitialized @basedir)
     assert_equal '/PART', params.part_file
     assert_equal '.re', params.ext
     assert_equal '/images', params.image_dir
     assert_equal %w(.ai .psd .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif .svg), params.image_types
   end
end
