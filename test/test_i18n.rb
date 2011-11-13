# -*- coding: utf-8 -*-
require 'test_helper'
require 'review/i18n'

class I18nTest < Test::Unit::TestCase
  include ReVIEW

  def test_ja
    I18n.i18n = "ja"
    assert_equal I18n.t("image"), "図"
    assert_equal I18n.t("table"), "表"
    assert_equal I18n.t("etc"), "etc"
  end

  def test_en
    I18n.i18n = "en"
    assert_equal I18n.t("image"), "Figure"
    assert_equal I18n.t("table"), "Table"
    assert_equal I18n.t("etc"), "etc"
  end

  def test_nil
    I18n.i18n = "nil"
    assert_equal I18n.t("image"), "image"
    assert_equal I18n.t("table"), "table"
    assert_equal I18n.t("etc"), "etc"
  end

  def teardown
    I18n.i18n = "ja"
  end
end
