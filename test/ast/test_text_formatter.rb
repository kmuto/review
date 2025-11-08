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

  # Test format_chapter_number
  def test_format_chapter_number_numeric
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number(1)
    # Expected: "第1章"
    assert_match(/第.*章/, result)
  end

  def test_format_chapter_number_appendix
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number('A')
    # Expected: I18n translation for appendix
    # If I18n returns the key itself when translation is missing, that's OK
    assert result.include?('A') || result.include?('appendix')
  end

  def test_format_chapter_number_part
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number('II')
    # Expected: I18n translation for part
    # If I18n returns the key itself when translation is missing, that's OK
    assert result.include?('II') || result.include?('part')
  end

  def test_format_chapter_number_empty
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    result = formatter.format_chapter_number('')
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

  # Test format_reference with image
  def test_format_reference_image_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config, chapter: @chapter)
    data = ResolvedData.image(
      chapter_number: '1',
      item_number: 1,
      item_id: 'sample-image'
    )
    result = formatter.format_reference(:image, data)
    assert_match(/図/, result)
    assert_match(/1\.1/, result)
  end

  def test_format_reference_image_latex
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    data = ResolvedData.image(
      chapter_number: '1',
      item_number: 2,
      item_id: 'test-img'
    )
    result = formatter.format_reference(:image, data)
    # LaTeX should use \ref{item_id}
    assert_match(/\\ref/, result)
    assert_match(/test-img/, result)
  end

  def test_format_reference_image_cross_chapter
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    data = ResolvedData.image(
      chapter_number: '2',
      item_number: 3,
      item_id: 'other-img',
      chapter_id: 'chapter2'
    )
    result = formatter.format_reference(:image, data)
    # Cross-chapter reference should include chapter_id
    assert_match(/\\ref/, result)
    assert_match(/chapter2/, result)
  end

  # Test format_reference with table
  def test_format_reference_table_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config, chapter: @chapter)
    data = ResolvedData.table(
      chapter_number: '1',
      item_number: 1,
      item_id: 'sample-table'
    )
    result = formatter.format_reference(:table, data)
    assert_match(/表/, result)
  end

  def test_format_reference_table_idgxml
    formatter = AST::TextFormatter.new(format_type: :idgxml, config: @config)
    data = ResolvedData.table(
      chapter_number: '1',
      item_number: 2,
      item_id: 'test-table'
    )
    result = formatter.format_reference(:table, data)
    assert_match(/表/, result)
  end

  # Test format_reference with list
  def test_format_reference_list_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config, chapter: @chapter)
    data = ResolvedData.list(
      chapter_number: '1',
      item_number: 3,
      item_id: 'code-example'
    )
    result = formatter.format_reference(:list, data)
    assert_match(/リスト/, result)
  end

  # Test format_reference with equation
  def test_format_reference_equation_latex
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    data = ResolvedData.equation(
      chapter_number: '1',
      item_number: 1,
      item_id: 'pythagorean'
    )
    result = formatter.format_reference(:equation, data)
    assert_match(/\\ref/, result)
    assert_match(/pythagorean/, result)
  end

  def test_format_reference_equation_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config, chapter: @chapter)
    data = ResolvedData.equation(
      chapter_number: '1',
      item_number: 2,
      item_id: 'einstein'
    )
    result = formatter.format_reference(:equation, data)
    assert_match(/式/, result)
  end

  # Test format_reference with footnote
  def test_format_reference_footnote_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.footnote(
      item_number: 5,
      item_id: 'fn1'
    )
    result = formatter.format_reference(:footnote, data)
    assert_equal '5', result
  end

  def test_format_reference_footnote_latex
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    data = ResolvedData.footnote(
      item_number: 3,
      item_id: 'fn2'
    )
    result = formatter.format_reference(:footnote, data)
    assert_match(/\\footnotemark/, result)
    assert_match(/3/, result)
  end

  def test_format_reference_footnote_top
    formatter = AST::TextFormatter.new(format_type: :top, config: @config)
    data = ResolvedData.footnote(
      item_number: 7,
      item_id: 'fn3'
    )
    result = formatter.format_reference(:footnote, data)
    assert_match(/【注/, result)
    assert_match(/7/, result)
  end

  # Test format_reference with endnote
  def test_format_reference_endnote_top
    formatter = AST::TextFormatter.new(format_type: :top, config: @config)
    data = ResolvedData.endnote(
      item_number: 2,
      item_id: 'en1'
    )
    result = formatter.format_reference(:endnote, data)
    assert_match(/【後注/, result)
    assert_match(/2/, result)
  end

  # Test format_reference with chapter
  def test_format_reference_chapter_with_title
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.chapter(
      chapter_number: '1',
      chapter_id: 'intro',
      chapter_title: 'Introduction'
    )
    result = formatter.format_reference(:chapter, data)
    assert_match(/Introduction/, result)
  end

  def test_format_reference_chapter_without_title
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.chapter(
      chapter_number: '2',
      chapter_id: 'chapter2'
    )
    result = formatter.format_reference(:chapter, data)
    assert_match(/第.*章/, result)
  end

  # Test format_reference with headline
  def test_format_reference_headline_with_number
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    caption_node = TextNode.new(content: 'Section Title', location: nil)
    data = ResolvedData.headline(
      headline_number: [1, 2],
      item_id: 'sec-1-2',
      chapter_number: '1',
      caption_node: caption_node
    )
    result = formatter.format_reference(:headline, data)
    assert_match(/Section Title/, result)
    assert_match(/1\.1\.2/, result)
  end

  def test_format_reference_headline_without_number
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    caption_node = TextNode.new(content: 'Unnumbered Section', location: nil)
    data = ResolvedData.headline(
      headline_number: [],
      item_id: 'unnumbered',
      caption_node: caption_node
    )
    result = formatter.format_reference(:headline, data)
    assert_match(/Unnumbered Section/, result)
  end

  # Test format_reference with column
  def test_format_reference_column
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    caption_node = TextNode.new(content: 'Column Title', location: nil)
    data = ResolvedData.column(
      chapter_number: '1',
      item_number: 1,
      item_id: 'col1',
      caption_node: caption_node
    )
    result = formatter.format_reference(:column, data)
    assert_match(/Column Title/, result)
  end

  # Test format_reference with word
  def test_format_reference_word
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.word(
      word_content: 'important term',
      item_id: 'term1'
    )
    result = formatter.format_reference(:word, data)
    assert_match(/important term/, result)
  end

  # Test format_reference with bibpaper
  def test_format_reference_bibpaper_html
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.bibpaper(
      item_number: 3,
      item_id: 'knuth1984'
    )
    result = formatter.format_reference(:bibpaper, data)
    assert_match(/\[3\]/, result)
    assert_match(/bibref/, result)
  end

  def test_format_reference_bibpaper_latex
    formatter = AST::TextFormatter.new(format_type: :latex, config: @config)
    data = ResolvedData.bibpaper(
      item_number: 5,
      item_id: 'dijkstra1968'
    )
    result = formatter.format_reference(:bibpaper, data)
    assert_match(/\\reviewbibref/, result)
    assert_match(/\[5\]/, result)
    assert_match(/dijkstra1968/, result)
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

  # Test HTML reference with chapterlink config
  def test_html_reference_with_chapterlink_enabled
    config = @config.dup
    config['chapterlink'] = true
    config['htmlext'] = 'html'
    formatter = AST::TextFormatter.new(format_type: :html, config: config, chapter: @chapter)

    data = ResolvedData.image(
      chapter_number: '1',
      item_number: 1,
      item_id: 'sample-image',
      chapter_id: 'chapter1'
    )
    result = formatter.format_reference(:image, data)

    # Should include link
    assert_match(/<a href=/, result)
    assert_match(/chapter1\.html/, result)
    # ID normalization: hyphens are kept (not converted to underscores)
    assert_match(/sample-image/, result)
  end

  def test_html_reference_with_chapterlink_disabled
    config = @config.dup
    config['chapterlink'] = false
    formatter = AST::TextFormatter.new(format_type: :html, config: config, chapter: @chapter)

    data = ResolvedData.image(
      chapter_number: '1',
      item_number: 1,
      item_id: 'sample-image'
    )
    result = formatter.format_reference(:image, data)

    # Should not include link
    refute_match(/<a href=/, result)
    assert_match(/<span/, result)
  end

  # Test text format references (include caption)
  def test_format_reference_image_text_format_with_caption
    formatter = AST::TextFormatter.new(format_type: :text, config: @config)
    caption_node = TextNode.new(content: 'Sample Caption', location: nil)
    data = ResolvedData.image(
      chapter_number: '1',
      item_number: 1,
      item_id: 'img1',
      caption_node: caption_node
    )
    result = formatter.format_reference(:image, data)

    # Text format should include caption
    assert_match(/図/, result)
    assert_match(/Sample Caption/, result)
  end

  # Test error handling for unknown reference type
  def test_format_reference_unknown_type
    formatter = AST::TextFormatter.new(format_type: :html, config: @config)
    data = ResolvedData.image(
      chapter_number: '1',
      item_number: 1,
      item_id: 'img1'
    )

    assert_raise(ArgumentError) do
      formatter.format_reference(:unknown_type, data)
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
end
