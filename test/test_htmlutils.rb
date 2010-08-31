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
end
