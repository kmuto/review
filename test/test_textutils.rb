require 'test_helper'
require 'review/textutils'

class TextUtilsTest < Test::Unit::TestCase
  include ReVIEW::TextUtils

  def setup
    @tu_nil = Object.new
    @tu_nil.extend(ReVIEW::TextUtils)
    def @tu_nil.pre_paragraph
      nil
    end

    def @tu_nil.post_paragraph
      nil
    end

    @tu_p = Object.new
    @tu_p.extend(ReVIEW::TextUtils)
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
    assert_equal ['<p>abc def</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', 'def'])
    assert_equal ['<p>abc</p>', '<p>def</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', '', 'def'])
    assert_equal ['<p>abc</p>', '<p>def</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', '', 'def', 'ghi'])
    assert_equal ['<p>abc</p>', '<p>def ghi</p>'], ret
    ret = @tu_p.split_paragraph(['abc', '', '', 'def', 'ghi', '', ''])
    assert_equal ['<p>abc</p>', '<p>def ghi</p>'], ret
  end

  def test_split_paragraph_nil
    ret = @tu_nil.split_paragraph(['abc'])
    assert_equal ['abc'], ret
    ret = @tu_nil.split_paragraph(['abc', 'def'])
    assert_equal ['abc def'], ret
    ret = @tu_nil.split_paragraph(['abc', '', 'def'])
    assert_equal ['abc', 'def'], ret
    ret = @tu_nil.split_paragraph(['abc', '', '', 'def'])
    assert_equal ['abc', 'def'], ret
    ret = @tu_nil.split_paragraph(['abc', '', '', 'def', 'ghi'])
    assert_equal ['abc', 'def ghi'], ret
  end

  def test_split_paragraph_p_lang
    ret = @tu_p.split_paragraph(['I', 'have.'])
    assert_equal ['<p>I have.</p>'], ret
    ret = @tu_p.split_paragraph(['I', 'have', '.'])
    assert_equal ['<p>I have .</p>'], ret # ...OK? (I have. ?)
    ret = @tu_p.split_paragraph(['01', '23', 'a', '4'])
    assert_equal ['<p>01 23 a 4</p>'], ret
    ret = @tu_p.split_paragraph(['こんにちは', '漢字', 'α', 'アルファ?', '！'])
    assert_equal ['<p>こんにちは漢字αアルファ?！</p>'], ret
    ret = @tu_p.split_paragraph(['こんにちは', '0814', '日'])
    assert_equal ['<p>こんにちは0814日</p>'], ret
    ret = @tu_p.split_paragraph(['あ', 'a', 'い', '?', 'a'])
    assert_equal ['<p>あaい? a</p>'], ret
    ret = @tu_p.split_paragraph(['안녕하세요', 'こんにちは'])
    assert_equal ['<p>안녕하세요こんにちは</p>'], ret
    ret = @tu_p.split_paragraph(['Hello', '안녕하세요', '처음뵙겠습니다'])
    assert_equal ['<p>Hello 안녕하세요 처음뵙겠습니다</p>'], ret
    ret = @tu_p.split_paragraph([''])
    assert_equal ['<p></p>'], ret
    # LaTeX
    ret = @tu_p.split_paragraph(['\tag{a}', 'A', '\tag{b}', 'B'])
    assert_equal ['<p>\tag{a} A \tag{b} B</p>'], ret
    ret = @tu_p.split_paragraph(['\tag{あ}', 'い', '\tag{う}', 'A', '\tag{え}', '\tag{b}', '\tag{お}', '\tag{か}'])
    assert_equal ['<p>\tag{あ}い\tag{う} A \tag{え} \tag{b} \tag{お} \tag{か}</p>'], ret # ...OK? (\tag{お}\tag{か}?)
    # HTML/IDGXML
    ret = @tu_p.split_paragraph(['<b>a</b>', 'A', '<b>b</b>', 'B'])
    assert_equal ['<p><b>a</b> A <b>b</b> B</p>'], ret
    ret = @tu_p.split_paragraph(['<b>あ</b>', 'い', '<b>う</b>', 'A', '<b>え</b>', '<b>b</b>', '<b>お</b>', '<b>か</b>'])
    assert_equal ['<p><b>あ</b>い<b>う</b> A <b>え</b> <b>b</b> <b>お</b> <b>か</b></p>'], ret # ...OK? (<b>お</b><b>か</b>?)
    # Text
    ret = @tu_p.split_paragraph(['★a☆', 'A', '★b☆', 'B'])
    assert_equal ['<p>★a☆ A ★b☆ B</p>'], ret
    ret = @tu_p.split_paragraph(['★あ☆', 'い', '★う☆', 'A', '★え☆', '★b☆', '★お☆', '★か☆'])
    assert_equal ['<p>★あ☆い★う☆ A ★え☆ ★b☆ ★お☆ ★か☆</p>'], ret # ...OK? (★お☆★か☆?)
  end
end
