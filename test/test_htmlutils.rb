require 'test_helper'
require 'review/htmlutils'

class HTMLUtilsTest < Test::Unit::TestCase
  include ReVIEW::HTMLUtils

  def test_escape_html
    assert_equal '&lt;', escape_html('<')
    assert_equal '&lt;&lt;', escape_html('<<')
    assert_equal '_&lt;_&lt;_', escape_html('_<_<_')
  end

  def test_escape_html_ex
    keys = ESC.keys
    ESC['.'] = 'X'
    ESC.each_pair do |ch, ref|
      if keys.include?(ch)
        assert_equal ref, escape_html(ch)
      else
        assert_equal ch, escape_html(ch)
      end
    end
  end

  def test_strip_html
    assert_equal 'thisistest.', strip_html('<h3>this<b>is</b>test</h3>.')
  end

  def test_escape_comment
    assert_equal '<', escape_comment('<')
    assert_equal '>', escape_comment('>')
    assert_equal '&', escape_comment('&')
    assert_equal '&#45;', escape_comment('-')
    assert_equal '&#45;&#45;', escape_comment('--')
  end

  def test_normalize_id
    assert_equal 'abcxyz', normalize_id('abcxyz')
    assert_equal 'ABCXYZ', normalize_id('ABCXYZ')
    assert_equal 'abc0123', normalize_id('abc0123')
    assert_equal 'a-b-c_x.y.z', normalize_id('a-b-c_x.y.z')
    assert_equal 'id_a_3Ab_3Ac', normalize_id('a:b:c')
    assert_equal 'id_0123a-b-c_x.y.z', normalize_id('0123a-b-c_x.y.z')
    assert_equal 'id_.', normalize_id('.')
    assert_equal 'id__E3_81_82', normalize_id('あ')
    assert_equal 'id_-___3B', normalize_id(' _;')
  end
end
