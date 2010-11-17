require 'test_helper'
require 'review/textutils'

class TextUtilsTest < Test::Unit::TestCase
  include ReVIEW::TextUtils

  def setup
  end

  def test_detab
    detabed = detab("\t\tabc")
    assert_equal "                abc", detabed
    detabed = detab("\tabc\tbcd")
    assert_equal "        abc     bcd", detabed
  end

  def test_detab_with_arg
    detabed = detab("\t\tabcd\tef",2)
    assert_equal "    abcd  ef", detabed
    detabed = detab("\tabc\tdef", 4)
    assert_equal "    abc def", detabed
  end
end
