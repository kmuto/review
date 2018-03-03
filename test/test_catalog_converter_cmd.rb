require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'

load File.expand_path('../bin/review-catalog-converter', File.dirname(__FILE__))

class CatalogConverterCmdTest < Test::Unit::TestCase
  def test_parse_chaps
    input = <<-EOS
ch01.re
ch02.re
ch03.re
    EOS

    expected = <<-EOS
CHAPS:
  - ch01.re
  - ch02.re
  - ch03.re

    EOS
    assert_equal expected, parse_chaps(input)
  end

  def test_parse_chaps_empty
    assert_equal "CHAPS:\n\n", parse_chaps('')
    assert_equal "CHAPS:\n\n", parse_chaps(nil)
  end

  def test_parse_parts
    parts = <<-EOS
pt01
pt02
pt03
    EOS

    chaps = <<-EOS
ch01.re

ch02.re
ch03.re

ch04.re
    EOS

    expected = <<-EOS
CHAPS:
  - pt01:
    - ch01.re
  - pt02:
    - ch02.re
    - ch03.re
  - pt03:
    - ch04.re

    EOS

    assert_equal expected, parse_parts(parts, chaps)
  end

  def test_parse_parts_chaps_empty
    assert_equal "CHAPS:\n\n", parse_parts('', '')
    assert_equal "CHAPS:\n\n", parse_parts(nil, nil)
  end

  def test_parse_postdef
    assert_equal "APPENDIX:\n\n", parse_postdef('', true)
    assert_equal "POSTDEF:\n\n", parse_postdef('')
    assert_equal "POSTDEF:\n\n", parse_postdef('', false)
  end
end
