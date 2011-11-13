# -*- coding: utf-8 -*-
require 'test_helper'
require 'review/i18n'

class I18nTest < Test::Unit::TestCase
  include ReVIEW

  def test_ja
    I18n.i18n = "ja"
    assert_equal I18n.t("image"), "図"
    assert_equal I18n.t("table"), "表"
  end

  def test_en
    I18n.i18n = "en"
    assert_equal I18n.t("image"), "Image"
    assert_equal I18n.t("table"), "Table"
  end
end
