# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../support/review/test/html_comparator'
require 'tmpdir'

class TestHtmlRendererJoinLinesByLang < Test::Unit::TestCase
  def test_join_lines_by_lang_disabled
    Dir.mktmpdir do |dir|
      setup_book(dir, join_lines_by_lang: false)

      File.write(File.join(dir, 'test.re'), <<~RE)
= Test

Japanese text
continues here

English text
continues here
      RE

      converter = ReVIEW::Test::HtmlComparator.new
      result = converter.convert_chapter_with_book_context(dir, 'test')

      assert_equal result[:builder], result[:renderer],
                   'Builder and Renderer should produce same output when join_lines_by_lang is disabled'

      # Without join_lines_by_lang, lines are joined without any separator
      assert result[:builder].include?('Japanese textcontinues here'),
             'Lines should be joined without space when join_lines_by_lang is disabled'
    end
  end

  def test_join_lines_by_lang_enabled_japanese
    Dir.mktmpdir do |dir|
      setup_book(dir, join_lines_by_lang: true)

      File.write(File.join(dir, 'test.re'), <<~RE)
= テスト

これは日本語の文章です。
複数行にわたっています。
      RE

      converter = ReVIEW::Test::HtmlComparator.new
      result = converter.convert_chapter_with_book_context(dir, 'test')

      assert_equal result[:builder], result[:renderer],
                   'Builder and Renderer should produce same output for Japanese text'

      # Japanese text should be joined without space
      assert result[:builder].include?('これは日本語の文章です。複数行にわたっています。'),
             'Japanese lines should be joined without space'
    end
  end

  def test_join_lines_by_lang_enabled_english
    Dir.mktmpdir do |dir|
      setup_book(dir, join_lines_by_lang: true)

      File.write(File.join(dir, 'test.re'), <<~RE)
= Test

This is English text.
It spans multiple lines.
      RE

      converter = ReVIEW::Test::HtmlComparator.new
      result = converter.convert_chapter_with_book_context(dir, 'test')

      assert_equal result[:builder], result[:renderer],
                   'Builder and Renderer should produce same output for English text'

      # English text should have space between lines
      assert result[:builder].include?('This is English text. It spans multiple lines.'),
             'English lines should be joined with space'
    end
  end

  def test_join_lines_by_lang_mixed_content
    Dir.mktmpdir do |dir|
      setup_book(dir, join_lines_by_lang: true)

      File.write(File.join(dir, 'test.re'), <<~RE)
= Test

日本語とEnglish混在
次の行です
      RE

      converter = ReVIEW::Test::HtmlComparator.new
      result = converter.convert_chapter_with_book_context(dir, 'test')

      assert_equal result[:builder], result[:renderer],
                   'Builder and Renderer should produce same output for mixed content'
    end
  end

  private

  def setup_book(dir, join_lines_by_lang:)
    config = {
      'bookname' => 'test',
      'language' => 'ja'
    }
    config['join_lines_by_lang'] = true if join_lines_by_lang

    File.write(File.join(dir, 'config.yml'), config.to_yaml)
    File.write(File.join(dir, 'catalog.yml'), <<~YAML)
      CHAPS:
        - test.re
    YAML
  end
end
