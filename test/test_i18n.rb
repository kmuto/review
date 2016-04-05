# -*- coding: utf-8 -*-
require 'test_helper'
require 'review'
require 'tmpdir'

class I18nTest < Test::Unit::TestCase
  include ReVIEW

  if RUBY_VERSION !~ /^1.8/ ## to avoid Travis error :-(
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

    def test_load_foo_yaml
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          file = File.join(dir, "foo.yml")
          File.open(file, "w"){|f| f.write("locale: ja\nfoo: \"bar\"\n")}
          I18n.setup("ja","foo.yml")
          assert_equal "bar", I18n.t("foo")
        end
      end
    end

    def test_update_foo_yaml
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          file = File.join(dir, "foo.yml")
          File.open(file, "w"){|f| f.write("locale: ja\nfoo: \"bar\"\n")}
          i18n = ReVIEW::I18n.new("ja")
          i18n.update_localefile(File.join(Dir.pwd, "foo.yml"))
          assert_equal "bar", i18n.t("foo")
        end
      end
    end

    def test_update_foo_yaml_i18nclass
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          file = File.join(dir, "foo.yml")
          File.open(file, "w"){|f| f.write("locale: ja\nfoo: \"bar\"\n")}
          I18n.setup("ja", "foo.yml")
          assert_equal "bar", I18n.t("foo")
        end
      end
    end

    def test_load_locale_yml_i18n
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          file = File.join(dir, "locale.yml")
          File.open(file, "w"){|f| f.write("ja:\n  foo: \"bar\"\nen:\n  foo: \"buz\"\n")}
          I18n.setup
          assert_equal "bar", I18n.t("foo")
          assert_equal "図", I18n.t("image")
          I18n.setup("en")
          assert_equal "buz", I18n.t("foo")
          assert_equal "Figure ", I18n.t("image")
        end
      end
    end

    def test_load_locale_invalid_yml
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          file = File.join(dir, "locale.yml")
          File.open(file, "w"){|f| f.write("local: ja\nfoo: \"bar\"\n")}
          assert_raises(ReVIEW::KeyError) do
            I18n.setup
          end
        end
      end
    end

    def test_custom_format
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          file = File.join(dir, "locale.yml")
          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pa章")}
          I18n.setup("ja")
          assert_equal "第a章", I18n.t("chapter", 1)

          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pA章")}
          I18n.setup("ja")
          assert_equal "第B章", I18n.t("chapter", 2)

          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pR章")}
          I18n.setup("ja")
          assert_equal "第I章", I18n.t("chapter", 1)

          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pr章")}
          I18n.setup("ja")
          assert_equal "第ii章", I18n.t("chapter", 2)

          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pAJ章")}
          I18n.setup("ja")
          assert_equal "第Ａ章", I18n.t("chapter", 1)
          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pAJ章")}
          I18n.setup("ja")
          assert_equal "第Ｂ章", I18n.t("chapter", 2)

          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pRJ章")}
          I18n.setup("ja")
          assert_equal "第Ｉ章", I18n.t("chapter", 1)
          File.open(file, "w"){|f| f.write("locale: ja\nchapter: 第%pRJ章")}
          I18n.setup("ja")
          assert_equal "第ＩＩ章", I18n.t("chapter", 2)
        end
      end
    end
  end

  def test_ja
    I18n.setup("ja")
    assert_equal "図", I18n.t("image")
    assert_equal "表", I18n.t("table")
    assert_equal "第1章", I18n.t("chapter", 1)
    assert_equal "etc", I18n.t("etc")
  end

  def test_ja_with_user_i18n
    i18n = I18n.new("ja")
    i18n.update({"image" => "ず"}, "ja")
    assert_equal "ず", i18n.t("image")
    assert_equal "表", i18n.t("table")
    assert_equal "第1章", i18n.t("chapter", 1)
    assert_equal "etc", i18n.t("etc")
  end

  def test_en
    I18n.setup "en"
    assert_equal "Figure ", I18n.t("image")
    assert_equal "Table ", I18n.t("table")
    assert_equal "Chapter 1", I18n.t("chapter", 1)
    assert_equal "etc", I18n.t("etc")
  end

  def test_nil
    I18n.setup "nil"
    assert_equal "image", I18n.t("image")
    assert_equal "table", I18n.t("table")
    assert_equal "etc", I18n.t("etc")
  end

  def test_htmlbuilder
    _setup_htmlbuilder
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a><span class="secno">Chapter 1. </span>this is test.</h1>\n|, actual
  end

  def _setup_htmlbuilder
    I18n.setup "en"
    @builder = HTMLBuilder.new()
    @config = {
      "secnolevel" => 2, # for IDGXMLBuilder, HTMLBuilder
      "stylesheet" => nil, # for HTMLBuilder
      "ext" => ".re"
    }
    @book = Book::Base.new(".")
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_update
    i18n = ReVIEW::I18n.new("ja")
    hash = {"foo"=>"bar"}
    i18n.update(hash)
    assert_equal "bar", i18n.t("foo")
  end

  def test_update_newlocale
    i18n = ReVIEW::I18n.new("ja")
    hash = {"foo"=>"bar"}
    i18n.update(hash, "abc")
    i18n.locale = "abc"
    assert_equal "bar", i18n.t("foo")
  end

  def test_ja_appendix_alphabet
    i18n = I18n.new("ja")
    i18n.update({"appendix" => "付録%pA"}, "ja")
    assert_equal "付録A", i18n.t("appendix", 1)
    assert_equal "付録B", i18n.t("appendix", 2)
    assert_equal "付録C", i18n.t("appendix", 3)
  end

  def test_i18n_error
    I18n.setup
    assert_raises NotImplementedError do
      I18n.i18n("ja")
    end
    assert_raises NotImplementedError do
      I18n.i18n("ja",{})
    end
  end

  def teardown
    I18n.setup "ja"
  end
end
