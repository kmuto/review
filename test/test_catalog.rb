require 'test_helper'
require 'review/catalog'

class CatalogTest < Test::Unit::TestCase
  include ReVIEW

  def test_predef
    sut = Catalog.new(yaml)
    exp = <<-EOS
pre01.re
pre02.re
    EOS
    assert_equal(exp.chomp, sut.predef)
  end

  def test_chaps
    sut = Catalog.new(yaml)
    exp = <<-EOS
ch01.re
ch02.re
    EOS
    assert_equal(exp.chomp, sut.chaps)
  end

  def test_chaps_empty
    yaml = StringIO.new
    sut = Catalog.new(yaml)
    assert_equal('', sut.chaps)
  end

  def test_appendix
    sut = Catalog.new(yaml)
    exp = <<-EOS
post01.re
post02.re
    EOS
    assert_equal(exp.chomp, sut.appendix)
  end

  def test_chaps_with_parts
    sut = Catalog.new(yaml_with_parts)
    exp = <<-EOS
ch01.re
ch02.re
ch03.re
ch04.re
ch05.re
    EOS
    assert_equal(exp.chomp, sut.chaps)
  end

  def test_parts
    sut = Catalog.new(yaml_with_parts)
    exp = <<-EOS
part1.re
part2.re
    EOS
    assert_equal(exp.chomp, sut.parts)
  end

  def test_parts_with_empty
    sut = Catalog.new(yaml)
    assert_equal('', sut.parts)
  end

  def test_parts2
    sut = Catalog.new(yaml_with_parts)
    assert_equal(['ch01.re',
                  { 'part1.re' => ['ch02.re'] },
                  'ch03.re',
                  { 'part2.re' => ['ch04.re', 'ch05.re'] }],
                 sut.parts_with_chaps)
  end

  def test_postdef
    sut = Catalog.new(yaml)
    exp = <<-EOS
back01.re
back02.re
    EOS
    assert_equal(exp.chomp, sut.postdef)
  end

  def test_from_object
    sut = Catalog.new(yaml_hash)
    exp = <<-EOS
ch01.re
ch02.re
    EOS
    assert_equal(exp.chomp, sut.chaps)
  end

  private

  def yaml
    StringIO.new <<-EOS

PREDEF:
  - pre01.re
  - pre02.re

CHAPS:
  - ch01.re
  - ch02.re

APPENDIX:
  - post01.re
  - post02.re

POSTDEF:
  - back01.re
  - back02.re
    EOS
  end

  def yaml_hash
    { 'PREDEF' => %w[pre01.re pre02.re],
      'CHAPS' => %w[ch01.re ch02.re],
      'APPENDIX' => %w[post01.re post02.re],
      'POSTDEF' => %w[back01.re back02.re] }
  end

  def yaml_with_parts
    StringIO.new <<-EOS
CHAPS:
  - ch01.re
  - part1.re:
    - ch02.re
  - ch03.re
  - part2.re:
    - ch04.re
    - ch05.re

    EOS
  end
end
