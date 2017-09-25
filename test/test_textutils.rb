require 'test_helper'
require 'review/textutils'

class TextUtilsTest < Test::Unit::TestCase
  include ReVIEW::TextUtils

  def setup
    @tu_nil = Object.new
    @tu_nil.extend ReVIEW::TextUtils
    def @tu_nil.pre_paragraph
      nil
    end

    def @tu_nil.post_paragraph
      nil
    end

    @tu_p = Object.new
    @tu_p.extend ReVIEW::TextUtils
    def @tu_p.pre_paragraph
      '<p>'
    end

    def @tu_p.post_paragraph
      '</p>'
    end
  end

  def test_detab
    detabed = detab("\t\tabc")
    assert_equal '                abc', detabed
    detabed = detab("\tabc\tbcd")
    assert_equal '        abc     bcd', detabed
  end

  def test_detab_with_arg
    detabed = detab("\t\tabcd\tef", 2)
    assert_equal '    abcd  ef', detabed
    detabed = detab("\tabc\tdef", 4)
    assert_equal '    abc def', detabed
  end

  def test_split_paragraph_empty_nil
    ret = @tu_nil.split_paragraph([])
    assert_equal ret, ['']
  end

  def test_split_paragraph_empty_p
    ret = @tu_p.split_paragraph([])
    assert_equal ret, ['<p></p>']
  end

  def test_split_paragraph_p
    ret = @tu_p.split_paragraph(['abc'])
    assert_equal ['<p>abc</p>'], ret
    ret = @tu_p.split_paragraph(['abc', 'def'])
    assert_equal ['<p>abcdef</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', 'def'])
    assert_equal ['<p>abc</p>', '<p>def</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', '', 'def'])
    assert_equal ['<p>abc</p>', '<p>def</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', '', 'def', 'ghi'])
    assert_equal ['<p>abc</p>', '<p>defghi</p>'], ret
  end

  def test_split_paragraph_nil
    ret = @tu_nil.split_paragraph(['abc'])
    assert_equal ['abc'], ret
    ret = @tu_nil.split_paragraph(['abc', 'def'])
    assert_equal ['abcdef'], ret
    ret = @tu_nil.split_paragraph(['abc', '', 'def'])
    assert_equal ['abc', 'def'], ret
    ret = @tu_nil.split_paragraph(['abc', '', '', 'def'])
    assert_equal ['abc', 'def'], ret
    ret = @tu_nil.split_paragraph(['abc', '', '', 'def', 'ghi'])
    assert_equal ['abc', 'defghi'], ret
  end
end
