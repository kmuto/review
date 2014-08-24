# -*- coding: utf-8 -*-
require 'test_helper'
require 'review/i18n'

require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'

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
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>Chapter 1. this is test.</h1>\n|, actual
  end

  def _setup_htmlbuilder
    I18n.i18n "en"
    @builder = HTMLBuilder.new()
    @config = {
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "stylesheet" => nil,  # for HTMLBuilder
      "ext" => ".re"
    }
    @book = Book::Base.new(".")
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def teardown
    I18n.i18n "ja"
  end
end
