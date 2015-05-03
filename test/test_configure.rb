# encoding: utf-8

require 'test_helper'
require 'review/pdfmaker'

class PDFMakerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @maker = ReVIEW::PDFMaker.new
    @config = ReVIEW::Configure.values
    @config.merge!({
                     "bookname" => "sample",
                     "title" => "Sample Book",
                     "version" => 2,
                     "urnid" => "http://example.jp/",
                     "date" => "2011-01-01",
                     "language" => "ja",
                     "epubmaker" => {"flattocindent" => true},
                   })
    @output = StringIO.new
    I18n.setup(@config["language"])
  end

  def test_configure_get
    bookname = @config["bookname"]
    assert_equal "sample", bookname
  end

  def test_configure_get2
    assert_equal true, @config["epubmaker"]["flattocindent"]
  end

  def test_configure_with_maker
    @config.maker = "epubmaker"
    assert_equal true, @config["flattocindent"]
    assert_equal true, @config["epubmaker"]["flattocindent"]
  end

  def test_configure_with_invalidmaker
    @config.maker = "pdfmaker"
    assert_equal nil, @config["flattocindent"]
    assert_equal true, @config["epubmaker"]["flattocindent"]
  end

end
