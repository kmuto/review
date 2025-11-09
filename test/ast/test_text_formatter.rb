# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/text_formatter'
require 'review/ast/resolved_data'
require 'review/ast'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'

class TestTextFormatter < Test::Unit::TestCase
  include ReVIEW
  include ReVIEW::AST

  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)

    ReVIEW::I18n.setup('ja')
  end

  # Test initialization
  def test_initialize_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    assert_equal :html, formatter.format_type
    assert_equal @config, formatter.config
  end

  def test_initialize_latex
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    assert_equal :latex, formatter.format_type
  end

  def test_initialize_with_chapter
    formatter = AST::TextFormatter.new(format_type: :html, config: @config, chapter: @chapter)
    assert_equal @chapter, formatter.chapter
  end

  # Test format_caption
  def test_format_caption_html_with_caption_text
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_caption('image', '第1章', 1, 'Sample Image')
    # Expected: "図1.1: Sample Image" (with I18n)
    assert_match(/図/, result)
    assert_match(/Sample Image/, result)
  end

  def test_format_caption_html_without_caption_text
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_caption('image', '第1章', 1, nil)
    # Should return just the label and number
    assert_match(/図/, result)
    refute_match(/nil/, result)
  end

  def test_format_caption_latex
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    result = formatter.format_caption('table', '第2章', 3, 'Test Table')
    assert_match(/表/, result)
    assert_match(/Test Table/, result)
  end

  def test_format_caption_idgxml
    formatter = AST::TextFormatter.new(format_type: :idgxml, config: @config)
    result = formatter.format_caption('list', '第1章', 2, 'Code Example')
    assert_match(/リスト/, result)
    assert_match(/Code Example/, result)
  end

  def test_format_caption_without_chapter_number
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_caption('image', nil, 5, 'No Chapter')
    assert_match(/図/, result)
    assert_match(/5/, result)
  end

  # Test format_number
  def test_format_number_with_chapter
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_number('1', 3)
    # Expected: "1.3"
    assert_match(/1\.3/, result)
  end

  def test_format_number_without_chapter
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_number(nil, 7)
    assert_match(/7/, result)
  end

  def test_format_number_with_appendix
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_number('A', 2)
    # Expected: "A.2"
    assert_match(/A\.2/, result)
  end

  # Test format_number_header
  def test_format_number_header_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_number_header('1', 1)
    # Should include colon in HTML format
    assert_match(/1\.1/, result)
  end

  def test_format_number_header_without_chapter
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_number_header(nil, 5)
    assert_match(/5/, result)
  end

  # Test format_chapter_number_full
  def test_format_chapter_number_full_numeric
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number_full(1, :chapter)
    # Expected: "第1章"
    assert_match(/第.*章/, result)
  end

  def test_format_chapter_number_full_appendix
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number_full(1, :appendix)
    # Expected: I18n translation for appendix
    # I18n.t('appendix', 1) returns formatted appendix number
    assert result.is_a?(String)
  end

  def test_format_chapter_number_full_part
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number_full(2, :part)
    # Expected: I18n translation for part
    # I18n.t('part', 2) returns formatted part number
    assert result.is_a?(String)
  end

  def test_format_chapter_number_full_empty
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number_full(nil, :chapter)
    assert_equal '', result
  end

  # Test footnote/endnote formatting
  def test_format_footnote_mark
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_footnote_mark(3)
    assert_match(/3/, result)
  end

  def test_format_endnote_mark
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_endnote_mark(5)
    assert_match(/5/, result)
  end

  def test_format_footnote_textmark
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_footnote_textmark(2)
    assert_match(/2/, result)
  end

  # Test format_column_label
  def test_format_column_label
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_column_label('Advanced Topic')
    assert_match(/Advanced Topic/, result)
  end

  # Test format_label_marker
  def test_format_label_marker_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_label_marker('my-label')
    assert_match(/my-label/, result)
  end

  def test_format_label_marker_html_escaping
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_label_marker('<script>')
    # Should escape HTML
    refute_match(/<script>/, result)
  end

  # Test format_headline_quote
  def test_format_headline_quote_with_number
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_headline_quote('1.2.3', 'Section Title')
    assert_match(/1\.2\.3/, result)
    assert_match(/Section Title/, result)
  end

  def test_format_headline_quote_without_number
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_headline_quote(nil, 'Unnumbered')
    assert_match(/Unnumbered/, result)
  end

  # Test format_image_quote (IDGXML specific)
  def test_format_image_quote_idgxml
    formatter = AST::TextFormatter.new(format_type: :idgxml, config: @config)
    result = formatter.format_image_quote('Sample Image')
    assert_match(/Sample Image/, result)
  end

  # Test format_numberless_image
  def test_format_numberless_image
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_numberless_image
    assert result.is_a?(String)
  end

  # Test format_caption_prefix
  def test_format_caption_prefix
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_caption_prefix
    assert result.is_a?(String)
  end

  # Test error handling for unknown reference type
  def test_format_reference_text_unknown_type
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.image(
      chapter_number: 1,
      item_number: 1,
      item_id: 'img1',
      chapter_type: :chapter
    )

    assert_raise(ArgumentError) do
      formatter.format_reference_text(:unknown_type, data)
    end
  end

  # Test format_part_short
  def test_format_part_short
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    chapter = ReVIEW::Book::Chapter.new(@book, 'II', 'part2', 'part2.re', StringIO.new)
    result = formatter.format_part_short(chapter)
    # I18n translation for part_short, or key itself
    assert result.include?('II') || result.include?('part_short')
  end

  # Test format_reference_text (plain text output without format-specific decorations)
  def test_format_reference_text_image
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.image(
      chapter_number: 1,
      item_number: 1,
      item_id: 'img1',
      chapter_type: :chapter
    )
    result = formatter.format_reference_text(:image, data)
    # Should return plain text like "図1.1" without HTML tags
    assert_equal '図1.1', result
    assert_no_match(/</, result) # No HTML tags
  end

  def test_format_reference_text_table
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.table(
      chapter_number: 2,
      item_number: 3,
      item_id: 'tbl1',
      chapter_type: :chapter
    )
    result = formatter.format_reference_text(:table, data)
    assert_equal '表2.3', result
    assert_no_match(/</, result)
  end

  def test_format_reference_text_list
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.list(
      chapter_number: 1,
      item_number: 2,
      item_id: 'list1',
      chapter_type: :chapter
    )
    result = formatter.format_reference_text(:list, data)
    assert_equal 'リスト1.2', result
    assert_no_match(/</, result)
  end

  def test_format_reference_text_equation
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.equation(
      chapter_number: 3,
      item_number: 1,
      item_id: 'eq1',
      chapter_type: :chapter
    )
    result = formatter.format_reference_text(:equation, data)
    assert_equal '式3.1', result
    assert_no_match(/</, result)
  end

  def test_format_reference_text_footnote
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.footnote(
      item_number: 5,
      item_id: 'fn1'
    )
    result = formatter.format_reference_text(:footnote, data)
    assert_equal '5', result
  end

  def test_format_reference_text_chapter
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.chapter(
      chapter_number: 1,
      chapter_id: 'ch01',
      item_id: 'ch01',
      chapter_title: 'Introduction',
      chapter_type: :chapter
    )
    result = formatter.format_reference_text(:chapter, data)
    # Should include chapter number and title formatted by I18n
    assert_match(/第1章/, result)
    assert_match(/Introduction/, result)
  end

  def test_format_reference_text_word
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.word(
      word_content: 'Ruby',
      item_id: 'ruby'
    )
    result = formatter.format_reference_text(:word, data)
    assert_equal 'Ruby', result
  end
end
