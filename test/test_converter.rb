require 'test_helper'
require 'book_test_helper'
require 'review/converter'

class ConverterTest < Test::Unit::TestCase
  include BookTestHelper

  def setup
  end

  def test_converter_builder
    mktmpbookdir('config.yml'=>"bookname: book\n") do |dir, book, files|
      @book = Book::Base.new(dir)
      config_file = File.join(dir,"config.yml")
      @book.load_config(config_file)
      @converter = ReVIEW::Converter.new(@book, ReVIEW::LATEXBuilder.new)
      assert_equal "latex", @book.config["builder"]
    end
  end
  
end
