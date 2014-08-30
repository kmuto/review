# -*- coding: utf-8 -*-
require 'test_helper'
require 'review/i18n'

require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'
require 'tmpdir'

class I18nTest < Test::Unit::TestCase
  include ReVIEW

  def test_load_locale_yml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, "locale.yml")
        File.open(file, "w"){|f| f.write("locale: ja\nfoo: \"bar\"\n")}
        I18n.setup
        assert_equal "bar", I18n.t("foo")
      end
    end
  end

  def test_load_locale_yaml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, "locale.yaml")
        File.open(file, "w"){|f| f.write("locale: ja\nfoo: \"bar\"\n")}
        I18n.setup
        assert_equal "bar", I18n.t("foo")
      end
    end
  end

  def test_ja
    I18n.i18n "ja"
    assert_equal "図", I18n.t("image")
    assert_equal "表", I18n.t("table")
    assert_equal "第1章", I18n.t("chapter", 1)
    assert_equal "etc", I18n.t("etc")
  end

  def test_ja_with_user_i18n
    I18n.i18n "ja", {"image" => "ず"}
    assert_equal "ず", I18n.t("image")
    assert_equal "表", I18n.t("table")
    assert_equal "第1章", I18n.t("chapter", 1) 
    assert_equal "etc", I18n.t("etc")
  end

  def test_en
    I18n.i18n "en"
    assert_equal "Figure ", I18n.t("image")
    assert_equal "Table ", I18n.t("table")
    assert_equal "Chapter 1", I18n.t("chapter", 1)
    assert_equal "etc", I18n.t("etc")
  end

  def test_nil
    I18n.i18n "nil"
    assert_equal "image", I18n.t("image")
    assert_equal "table", I18n.t("table")
    assert_equal "etc", I18n.t("etc")
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
