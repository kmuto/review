# -*- coding: utf-8 -*-
require 'test_helper'
require 'review/i18n'

class I18nTest < Test::Unit::TestCase
  include ReVIEW

  def test_ja
    I18n.i18n "ja"
    assert_equal I18n.t("image"), "図"
    assert_equal I18n.t("table"), "表"
    assert_equal I18n.t("chapter", 1), "第1章"
    assert_equal I18n.t("etc"), "etc"
  end

  def test_ja_with_user_i18n
    I18n.i18n "ja", {"image" => "ず"}
    assert_equal I18n.t("image"), "ず"
    assert_equal I18n.t("table"), "表"
    assert_equal I18n.t("chapter", 1), "第1章"
    assert_equal I18n.t("etc"), "etc"
  end

  def test_en
    I18n.i18n "en"
    assert_equal I18n.t("image"), "Figure "
    assert_equal I18n.t("table"), "Table "
    assert_equal I18n.t("chapter", 1), "Chapter 1"
    assert_equal I18n.t("etc"), "etc"
  end

  def test_nil
    I18n.i18n "nil"
    assert_equal I18n.t("image"), "image"
    assert_equal I18n.t("table"), "table"
    assert_equal I18n.t("etc"), "etc"
  end

  def test_htmlbuilder
    _setup_htmlbuilder
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<h1 id="test"><a id="h1" />Chapter 1. this is test.</h1>\n|, @builder.raw_result
  end

  def _setup_htmlbuilder
    I18n.i18n "en"
    @builder = HTMLBuilder.new()
    @param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "stylesheet" => nil,  # for HTMLBuilder
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Chapter.new(nil, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def teardown
    I18n.i18n "ja"
  end
end
