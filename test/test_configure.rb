require 'test_helper'
require 'review/epubmaker'

class ConfigureTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @maker = ReVIEW::EPUBMaker.new
    @config = ReVIEW::Configure.values
    @config.merge!(
      'bookname' => 'sample',
      'title' => 'Sample Book',
      'version' => 2,
      'urnid' => 'http://example.jp/',
      'date' => '2011-01-01',
      'language' => 'ja',
      'epubmaker' => { 'flattocindent' => true,
                       'title' => 'Sample Book(EPUB)' }
    )
    @output = StringIO.new
    I18n.setup(@config['language'])
  end

  def test_configure_class
    assert_equal ReVIEW::Configure, @config.class
  end

  def test_configure_get
    bookname = @config['bookname']
    assert_equal 'sample', bookname
  end

  def test_configure_get2
    assert_equal true, @config['epubmaker']['flattocindent']
  end

  def test_configure_with_maker
    @config.maker = 'epubmaker'
    assert_equal true, @config['flattocindent']
    assert_equal true, @config['epubmaker']['flattocindent']
  end

  def test_configure_with_maker_override
    @config.maker = 'epubmaker'
    assert_equal 'Sample Book(EPUB)', @config['title']
    @config.maker = 'pdfmaker'
    assert_equal 'Sample Book', @config['title']
  end

  def test_configure_with_invalidmaker
    @config.maker = 'pdfmaker'
    assert_equal nil, @config['flattocindent']
    assert_equal true, @config['epubmaker']['flattocindent']
  end

  def test_check_version_nosetting
    @config.delete('review_version')
    assert_raise ReVIEW::ConfigError do
      @config.check_version('2.0.0')
    end
  end

  def test_check_version_noversion
    @config['review_version'] = nil
    assert_nothing_raised ReVIEW::ConfigError do
      @config.check_version('2.0.0')
    end
  end

  def test_check_version
    @config['review_version'] = '2.1'
    assert_nothing_raised do
      @config.check_version('2.1.0')
    end
    assert_nothing_raised do
      @config.check_version('2.2.0')
    end
    assert_nothing_raised do
      @config.check_version('2.2.5')
    end
    assert_raise ReVIEW::ConfigError do
      @config.check_version('2.0.0')
    end
    assert_raise ReVIEW::ConfigError do
      @config.check_version('3.0.0')
    end
    assert_raise ReVIEW::ConfigError do
      @config.check_version('1.8.0')
    end
  end
end
