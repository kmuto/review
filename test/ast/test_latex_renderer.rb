# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require_relative '../test_helper'
require 'review/renderer/latex_renderer'
require 'review/ast'
require 'review/book'
require 'review/book/chapter'

class TestLatexRenderer < Test::Unit::TestCase
  include ReVIEW

  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @book.config = @config
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    @chapter.generate_indexes
    @book.generate_indexes

    @renderer = Renderer::LatexRenderer.new(@chapter)
  end

  def test_visit_text
    node = AST::TextNode.new(content: 'Hello World')
    result = @renderer.visit(node)
    assert_equal 'Hello World', result
  end

  def test_visit_text_with_special_characters
    node = AST::TextNode.new(content: 'Hello & World $ Test')
    result = @renderer.visit(node)
    assert_equal 'Hello \\& World \\textdollar{} Test', result
  end

  def test_visit_paragraph
    paragraph = AST::ParagraphNode.new
    text = AST::TextNode.new(content: 'This is a paragraph.')
    paragraph.add_child(text)

    result = @renderer.visit(paragraph)
    assert_equal "This is a paragraph.\n\n", result
  end

  def test_visit_paragraph_dual
    paragraph = AST::ParagraphNode.new
    text = AST::TextNode.new(content: "This is a paragraph.\n\nNext paragraph.\n")
    paragraph.add_child(text)

    result = @renderer.visit(paragraph)
    assert_equal "This is a paragraph.\n\nNext paragraph.\n\n\n", result
  end

  def test_visit_headline_level1
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Chapter Title'))

    headline = AST::HeadlineNode.new(level: 1, caption: caption, label: 'chap1')
    result = @renderer.visit(headline)

    assert_equal "\\chapter{Chapter Title}\n\\label{chap:test}\n", result
  end

  def test_visit_headline_level2
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    result = @renderer.visit(headline)

    assert_equal "\\section{Section Title}\n\\label{sec:1-1}\n", result
  end

  def test_visit_headline_with_secnolevel_default
    # Default secnolevel is 2, so level 3 should be subsection*
    @config['secnolevel'] = 2
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Subsection Title'))

    headline = AST::HeadlineNode.new(level: 3, caption: caption)
    result = @renderer.visit(headline)

    expected = "\\subsection*{Subsection Title}\n\\addcontentsline{toc}{subsection}{Subsection Title}\n\\label{sec:1-0-1}\n"
    assert_equal expected, result
  end

  def test_visit_headline_with_secnolevel3
    # secnolevel 3, so level 3 should be normal subsection, level 4 should be subsubsection*
    @config['secnolevel'] = 3

    # Level 3 - normal subsection
    caption3 = AST::CaptionNode.new
    caption3.add_child(AST::TextNode.new(content: 'Subsection Title'))
    headline3 = AST::HeadlineNode.new(level: 3, caption: caption3)
    result3 = @renderer.visit(headline3)
    assert_equal "\\subsection{Subsection Title}\n\\label{sec:1-0-1}\n", result3

    # Level 4 - subsubsection* with addcontentsline
    caption4 = AST::CaptionNode.new
    caption4.add_child(AST::TextNode.new(content: 'Subsubsection Title'))
    headline4 = AST::HeadlineNode.new(level: 4, caption: caption4)
    result4 = @renderer.visit(headline4)
    expected4 = "\\subsubsection*{Subsubsection Title}\n\\addcontentsline{toc}{subsection}{Subsubsection Title}\n\\label{sec:1-0-1-1}\n"
    assert_equal expected4, result4
  end

  def test_visit_headline_with_secnolevel1
    # secnolevel 1, so level 2 and above should be section*
    @config['secnolevel'] = 1
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    result = @renderer.visit(headline)

    expected = "\\section*{Section Title}\n\\addcontentsline{toc}{subsection}{Section Title}\n\\label{sec:1-1}\n"
    assert_equal expected, result
  end

  def test_visit_headline_numberless_chapter
    # Numberless chapter: level > 1 should get star commands
    @chapter.instance_variable_set(:@number, '') # Make chapter numberless
    @config['secnolevel'] = 3

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    result = @renderer.visit(headline)

    expected = "\\section*{Section Title}\n\\addcontentsline{toc}{subsection}{Section Title}\n\\label{sec:-1}\n"
    assert_equal expected, result
  end

  def test_visit_headline_secnolevel0
    # secnolevel 0 means all levels should be starred
    @config['secnolevel'] = 0

    # Level 1 - chapter*
    caption1 = AST::CaptionNode.new
    caption1.add_child(AST::TextNode.new(content: 'Chapter Title'))
    headline1 = AST::HeadlineNode.new(level: 1, caption: caption1)
    result1 = @renderer.visit(headline1)
    expected1 = "\\chapter*{Chapter Title}\n\\addcontentsline{toc}{subsection}{Chapter Title}\n\\label{chap:test}\n"
    assert_equal expected1, result1

    # Level 2 - section*
    caption2 = AST::CaptionNode.new
    caption2.add_child(AST::TextNode.new(content: 'Section Title'))
    headline2 = AST::HeadlineNode.new(level: 2, caption: caption2)
    result2 = @renderer.visit(headline2)
    expected2 = "\\section*{Section Title}\n\\addcontentsline{toc}{subsection}{Section Title}\n\\label{sec:1-1}\n"
    assert_equal expected2, result2
  end

  def test_visit_headline_part_level1
    # Test Part with level 1 - should use \part command
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Part Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: caption)
    result = part_renderer.visit(headline)

    expected = "\\begin{reviewpart}\n\\part{Part Title}\n\\label{chap:part1}\n"
    assert_equal expected, result
  end

  def test_visit_headline_part_with_secnolevel0
    # Test Part with secnolevel 0 - should use \part* command
    @config['secnolevel'] = 0
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Part Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: caption)
    result = part_renderer.visit(headline)

    expected = "\\begin{reviewpart}\n\\part*{Part Title}\n\\addcontentsline{toc}{subsection}{Part Title}\n\\label{chap:part1}\n"
    assert_equal expected, result
  end

  def test_visit_headline_part_level2
    # Test Part with level 2 - should use normal chapter/section commands
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Chapter in Part'))
    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    result = part_renderer.visit(headline)

    expected = "\\section{Chapter in Part}\n\\label{sec:1-1}\n"
    assert_equal expected, result
  end

  def test_visit_headline_numberless_part
    # Test numberless Part - level > 1 should get star commands
    @config['secnolevel'] = 3
    part = ReVIEW::Book::Part.new(@book, '', 'partx', 'partx.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Chapter in Numberless Part'))
    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    result = part_renderer.visit(headline)

    expected = "\\section*{Chapter in Numberless Part}\n\\addcontentsline{toc}{subsection}{Chapter in Numberless Part}\n\\label{sec:-1}\n"
    assert_equal expected, result
  end

  def test_visit_inline_bold
    inline = AST::InlineNode.new(inline_type: 'b')
    inline.add_child(AST::TextNode.new(content: 'bold text'))

    result = @renderer.visit(inline)
    assert_equal '\\reviewbold{bold text}', result
  end

  def test_visit_inline_italic
    inline = AST::InlineNode.new(inline_type: 'i')
    inline.add_child(AST::TextNode.new(content: 'italic text'))

    result = @renderer.visit(inline)
    assert_equal '\\reviewit{italic text}', result
  end

  def test_visit_inline_code
    inline = AST::InlineNode.new(inline_type: 'tt')
    inline.add_child(AST::TextNode.new(content: 'code text'))

    result = @renderer.visit(inline)
    assert_equal '\\reviewtt{code text}', result
  end

  def test_visit_inline_footnote
    inline = AST::InlineNode.new(inline_type: 'fn', args: ['footnote1'])

    result = @renderer.visit(inline)
    assert_equal '\\footnote{footnote1}', result
  end

  def test_visit_code_block_with_caption
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Code Example'))

    code_block = AST::CodeBlockNode.new(caption: caption, code_type: 'emlist')
    line1 = AST::CodeLineNode.new(location: nil)
    line1.add_child(AST::TextNode.new(content: 'puts "Hello"'))
    code_block.add_child(line1)

    result = @renderer.visit(code_block)
    expected = "\\begin{reviewlistblock}\n" +
               "\\reviewemlistcaption{Code Example}\n" +
               "\\begin{reviewemlist}\n" +
               "puts \"Hello\"\n" +
               "\\end{reviewemlist}\n" +
               "\\end{reviewlistblock}\n"

    assert_equal expected, result
  end

  def test_visit_table
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Test Table'))

    table = AST::TableNode.new(id: 'table1', caption: caption)

    # Header row
    header_row = AST::TableRowNode.new(location: nil)
    header_cell1 = AST::TableCellNode.new(location: nil, cell_type: :th)
    header_cell1.add_child(AST::TextNode.new(content: 'Header 1'))
    header_cell2 = AST::TableCellNode.new(location: nil, cell_type: :th)
    header_cell2.add_child(AST::TextNode.new(content: 'Header 2'))
    header_row.add_child(header_cell1)
    header_row.add_child(header_cell2)
    table.add_header_row(header_row)

    # Body row
    body_row = AST::TableRowNode.new(location: nil)
    body_cell1 = AST::TableCellNode.new(location: nil)
    body_cell1.add_child(AST::TextNode.new(content: 'Data 1'))
    body_cell2 = AST::TableCellNode.new(location: nil)
    body_cell2.add_child(AST::TextNode.new(content: 'Data 2'))
    body_row.add_child(body_cell1)
    body_row.add_child(body_cell2)
    table.add_body_row(body_row)

    result = @renderer.visit(table)

    expected_lines = [
      '\\begin{table}%%table1',
      '\\reviewtablecaption{Test Table}',
      '\\label{table:test:table1}',
      '\\begin{reviewtable}{|l|l|}',
      '\\hline',
      '\\reviewth{Header 1} & \\reviewth{Header 2} \\\\  \\hline',
      'Data 1 & Data 2 \\\\  \\hline',
      '\\end{reviewtable}',
      '\\end{table}'
    ]

    assert_equal expected_lines.join("\n") + "\n", result
  end

  def test_visit_image
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Test Image'))

    image = AST::ImageNode.new(id: 'image1', caption: caption)
    result = @renderer.visit(image)

    expected_lines = [
      '\\begin{reviewimage}%%image1',
      '\\reviewimagecaption{Test Image}',
      '\\label{image:test:image1}',
      '\\end{reviewimage}'
    ]

    assert_equal expected_lines.join("\n") + "\n", result
  end

  def test_visit_list_unordered
    list = AST::ListNode.new(list_type: :ul)

    item1 = AST::ListItemNode.new
    item1.add_child(AST::TextNode.new(content: 'First item'))

    item2 = AST::ListItemNode.new
    item2.add_child(AST::TextNode.new(content: 'Second item'))

    list.add_child(item1)
    list.add_child(item2)

    result = @renderer.visit(list)
    expected = "\n\\begin{itemize}\n\\item First item\n\\item Second item\n\\end{itemize}\n"

    assert_equal expected, result
  end

  def test_visit_list_ordered
    list = AST::ListNode.new(list_type: :ol)

    item1 = AST::ListItemNode.new
    item1.add_child(AST::TextNode.new(content: 'First item'))

    item2 = AST::ListItemNode.new
    item2.add_child(AST::TextNode.new(content: 'Second item'))

    list.add_child(item1)
    list.add_child(item2)

    result = @renderer.visit(list)
    expected = "\n\\begin{enumerate}\n\\item First item\n\\item Second item\n\\end{enumerate}\n"

    assert_equal expected, result
  end

  def test_visit_minicolumn_note
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Note Caption'))

    minicolumn = AST::MinicolumnNode.new(minicolumn_type: :note, caption: caption)
    minicolumn.add_child(AST::TextNode.new(content: 'This is a note.'))

    result = @renderer.visit(minicolumn)
    expected = "\\begin{reviewnote}[Note Caption]\n\nThis is a note.\n\n\\end{reviewnote}\n"

    assert_equal expected, result
  end

  def test_visit_document
    document = AST::DocumentNode.new

    # Add a paragraph
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'Hello World'))
    document.add_child(paragraph)

    result = @renderer.visit(document)
    assert_equal "Hello World\n\n", result
  end

  def test_render_inline_element_href_with_args
    inline = AST::InlineNode.new(inline_type: 'href', args: ['http://example.com', 'Example'])

    result = @renderer.visit(inline)
    assert_equal '\\href{http://example.com}{Example}', result
  end

  def test_generic_visitor_error
    # Create an unknown node type by using a BlockNode with unknown type
    unknown_node = AST::BlockNode.new(block_type: :UnknownNode)

    assert_raise(NotImplementedError) do
      @renderer.visit(unknown_node)
    end
  end

  def test_visit_part_document_with_reviewpart_environment
    # Test Part document wrapping with \begin{reviewpart} and \end{reviewpart}
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    # Create a document with a level 1 headline and some content
    document = AST::DocumentNode.new

    # Add level 1 headline (Part title)
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Part Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: caption)
    document.add_child(headline)

    # Add a paragraph
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'Part content here.'))
    document.add_child(paragraph)

    result = part_renderer.visit(document)

    expected = "\\begin{reviewpart}\n" +
               "\\part{Part Title}\n" +
               "\\label{chap:part1}\n" +
               "Part content here.\n\n" +
               "\\end{reviewpart}\n"

    assert_equal expected, result
  end

  def test_visit_part_document_multiple_headlines
    # Test that reviewpart environment is only opened once, even with multiple headlines
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    document = AST::DocumentNode.new

    # Add first level 1 headline
    caption1 = AST::CaptionNode.new
    caption1.add_child(AST::TextNode.new(content: 'Part Title'))
    headline1 = AST::HeadlineNode.new(level: 1, caption: caption1)
    document.add_child(headline1)

    # Add second level 1 headline (should not open reviewpart again)
    caption2 = AST::CaptionNode.new
    caption2.add_child(AST::TextNode.new(content: 'Another Part Title'))
    headline2 = AST::HeadlineNode.new(level: 1, caption: caption2)
    document.add_child(headline2)

    result = part_renderer.visit(document)

    expected = "\\begin{reviewpart}\n" +
               "\\part{Part Title}\n" +
               "\\label{chap:part1}\n" +
               "\\part{Another Part Title}\n" +
               "\\label{chap:part1}\n" +
               "\\end{reviewpart}\n"

    assert_equal expected, result
  end

  def test_visit_part_document_with_level_2_first
    # Test Part document that starts with level 2 headline (no reviewpart environment should be opened)
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    document = AST::DocumentNode.new

    # Add level 2 headline first (should not open reviewpart)
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Section Title'))
    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    document.add_child(headline)

    result = part_renderer.visit(document)

    expected = "\\section{Section Title}\n" +
               "\\label{sec:1-1}\n"

    assert_equal expected, result
  end

  def test_visit_chapter_document_no_reviewpart
    # Test that regular Chapter documents do not get reviewpart environment
    document = AST::DocumentNode.new

    # Add level 1 headline
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Chapter Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: caption)
    document.add_child(headline)

    # Add a paragraph
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'Chapter content here.'))
    document.add_child(paragraph)

    result = @renderer.visit(document)

    expected = "\\chapter{Chapter Title}\n" +
               "\\label{chap:test}\n" +
               "Chapter content here.\n\n"

    assert_equal expected, result
  end

  def test_visit_headline_nonum
    # Test [nonum] option - unnumbered section with TOC entry
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Unnumbered Section'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption, tag: 'nonum')
    result = @renderer.visit(headline)

    expected = "\\section*{Unnumbered Section}\n" +
               "\\addcontentsline{toc}{section}{Unnumbered Section}\n" +
               "\\label{sec:1-1}\n"

    assert_equal expected, result
  end

  def test_visit_headline_notoc
    # Test [notoc] option - unnumbered section without TOC entry
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'No TOC Section'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption, tag: 'notoc')
    result = @renderer.visit(headline)

    expected = "\\section*{No TOC Section}\n" +
               "\\label{sec:1-1}\n"

    assert_equal expected, result
  end

  def test_visit_headline_nodisp
    # Test [nodisp] option - TOC entry only, no visible heading
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Hidden Section'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption, tag: 'nodisp')
    result = @renderer.visit(headline)

    expected = "\\addcontentsline{toc}{section}{Hidden Section}\n"

    assert_equal expected, result
  end

  def test_visit_headline_nonum_level1
    # Test [nonum] option for level 1 (chapter)
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Unnumbered Chapter'))

    headline = AST::HeadlineNode.new(level: 1, caption: caption, tag: 'nonum')
    result = @renderer.visit(headline)

    expected = "\\chapter*{Unnumbered Chapter}\n" +
               "\\addcontentsline{toc}{chapter}{Unnumbered Chapter}\n" +
               "\\label{chap:test}\n"

    assert_equal expected, result
  end

  def test_visit_headline_nonum_level3
    # Test [nonum] option for level 3 (subsection)
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Unnumbered Subsection'))

    headline = AST::HeadlineNode.new(level: 3, caption: caption, tag: 'nonum')
    result = @renderer.visit(headline)

    expected = "\\subsection*{Unnumbered Subsection}\n" +
               "\\addcontentsline{toc}{subsection}{Unnumbered Subsection}\n" +
               "\\label{sec:1-0-1}\n"

    assert_equal expected, result
  end

  def test_visit_headline_part_nonum
    # Test [nonum] option for Part level 1
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Unnumbered Part'))
    headline = AST::HeadlineNode.new(level: 1, caption: caption, tag: 'nonum')
    result = part_renderer.visit(headline)

    expected = "\\begin{reviewpart}\n" +
               "\\part*{Unnumbered Part}\n" +
               "\\addcontentsline{toc}{chapter}{Unnumbered Part}\n" +
               "\\label{chap:part1}\n"

    assert_equal expected, result
  end

  def test_headline_node_tag_methods
    # Test HeadlineNode tag checking methods
    nonum_headline = AST::HeadlineNode.new(level: 2, tag: 'nonum')
    notoc_headline = AST::HeadlineNode.new(level: 2, tag: 'notoc')
    nodisp_headline = AST::HeadlineNode.new(level: 2, tag: 'nodisp')
    regular_headline = AST::HeadlineNode.new(level: 2)

    assert_true(nonum_headline.nonum?)
    assert_false(nonum_headline.notoc?)
    assert_false(nonum_headline.nodisp?)

    assert_false(notoc_headline.nonum?)
    assert_true(notoc_headline.notoc?)
    assert_false(notoc_headline.nodisp?)

    assert_false(nodisp_headline.nonum?)
    assert_false(nodisp_headline.notoc?)
    assert_true(nodisp_headline.nodisp?)

    assert_false(regular_headline.nonum?)
    assert_false(regular_headline.notoc?)
    assert_false(regular_headline.nodisp?)
  end

  def test_render_inline_column
    # Test that inline element rendering works with basic elements
    # Create a simple inline node
    inline_node = AST::InlineNode.new(inline_type: 'b')
    inline_node.add_child(AST::TextNode.new(content: 'bold text'))

    # Test that inline element processing works by visiting an inline node
    # This will internally create a new inline renderer each time (no caching)
    result = @renderer.visit_inline(inline_node)
    assert_true(result.is_a?(String), 'visit_inline should return a string')
    assert_match(/\\reviewbold\{bold text\}/, result, 'Result should contain LaTeX bold formatting')

    # Test that multiple calls work (each creating a new inline renderer)
    result2 = @renderer.visit_inline(inline_node)
    assert_equal(result, result2, 'Multiple calls should produce same result')
  end

  def test_visit_column_basic
    # Test basic column rendering
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Test Column'))

    column = AST::ColumnNode.new(level: 3, caption: caption, column_type: 'column')
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'Column content here.'))
    column.add_child(paragraph)

    result = @renderer.visit(column)

    # Should use version 3+ format by default
    expected = "\n" +
               "\\begin{reviewcolumn}[Test Column\\hypertarget{column:test:1}{}]\n" +
               "\\addcontentsline{toc}{subsection}{Test Column}\n" +
               "\n" +
               "Column content here.\n\n" +
               "\n" +
               "\\end{reviewcolumn}\n" +
               "\n"

    assert_equal expected, result
  end

  def test_visit_column_no_caption
    # Test column without caption
    column = AST::ColumnNode.new(level: 3, column_type: 'column')
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'No caption column.'))
    column.add_child(paragraph)

    result = @renderer.visit(column)

    expected = "\n" +
               "\\begin{reviewcolumn}[\\hypertarget{column:test:1}{}]\n" +
               "\n" +
               "No caption column.\n\n" +
               "\n" +
               "\\end{reviewcolumn}\n" +
               "\n"

    assert_equal expected, result
  end

  def test_visit_column_toclevel_filter
    # Test column TOC entry based on toclevel setting
    @config['toclevel'] = 2 # Only levels 1-2 should get TOC entries

    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Level 3 Column'))

    column = AST::ColumnNode.new(level: 3, caption: caption, column_type: 'column')
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'This should not get TOC entry.'))
    column.add_child(paragraph)

    result = @renderer.visit(column)

    # Should not contain addcontentsline since level 3 > toclevel 2
    expected = "\n" +
               "\\begin{reviewcolumn}[Level 3 Column\\hypertarget{column:test:1}{}]\n" +
               "\n" +
               "This should not get TOC entry.\n\n" +
               "\n" +
               "\\end{reviewcolumn}\n" +
               "\n"

    assert_equal expected, result
  end

  def test_visit_embed_raw_basic
    # Test basic //raw command without builder specification
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: 'Raw content with \\n newline',
      target_builders: nil,
      content: 'Raw content with \\n newline'
    )

    result = @renderer.visit(embed)
    expected = "Raw content with \n newline"

    assert_equal expected, result
  end

  def test_visit_embed_raw_latex_targeted
    # Test //raw command targeted for LaTeX
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|latex|\\textbf{Bold LaTeX text}',
      target_builders: ['latex'],
      content: '\\textbf{Bold LaTeX text}'
    )

    result = @renderer.visit(embed)
    expected = '\\textbf{Bold LaTeX text}'

    assert_equal expected, result
  end

  def test_visit_embed_raw_html_targeted
    # Test //raw command targeted for HTML (should output nothing)
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|html|<div>HTML content</div>',
      target_builders: ['html'],
      content: '<div>HTML content</div>'
    )

    result = @renderer.visit(embed)
    expected = ''

    assert_equal expected, result
  end

  def test_visit_embed_raw_complex_example
    # Test complex example: //raw[|html|<div class="custom">HTML用カスタム要素</div>]
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|html|<div class="custom">HTML用カスタム要素</div>',
      target_builders: ['html'],
      content: '<div class="custom">HTML用カスタム要素</div>'
    )

    result = @renderer.visit(embed)
    expected = '' # Should output nothing for LaTeX renderer

    assert_equal expected, result
  end

  def test_visit_embed_raw_latex_with_clearpage
    # Test: //raw[|latex|\clearpage]
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|latex|\\clearpage',
      target_builders: ['latex'],
      content: '\\clearpage'
    )

    result = @renderer.visit(embed)
    expected = '\\clearpage'

    assert_equal expected, result
  end

  def test_visit_embed_raw_multiple_builders
    # Test //raw command targeted for multiple builders including LaTeX
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: '|html,latex|Content for both',
      target_builders: ['html', 'latex'],
      content: 'Content for both'
    )

    result = @renderer.visit(embed)
    expected = 'Content for both'

    assert_equal expected, result
  end

  def test_visit_embed_raw_inline
    # Test inline @<raw> command
    embed = AST::EmbedNode.new(
      embed_type: :inline,
      arg: '|latex|\\LaTeX{}',
      target_builders: ['latex'],
      content: '\\LaTeX{}'
    )

    result = @renderer.visit(embed)
    expected = '\\LaTeX{}'

    assert_equal expected, result
  end

  def test_visit_embed_raw_newline_conversion
    # Test \n to newline conversion
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: 'Line 1\\nLine 2\\nLine 3',
      target_builders: nil,
      content: 'Line 1\\nLine 2\\nLine 3'
    )

    result = @renderer.visit(embed)
    expected = "Line 1\nLine 2\nLine 3"

    assert_equal expected, result
  end

  def test_visit_embed_raw_no_builder_specification
    # Test //raw without builder specification (should output content)
    embed = AST::EmbedNode.new(
      embed_type: :raw,
      arg: 'Raw content without builder spec',
      target_builders: nil,
      content: 'Raw content without builder spec'
    )

    result = @renderer.visit(embed)
    expected = 'Raw content without builder spec'

    assert_equal expected, result
  end

  def test_visit_list_definition
    # Test definition list
    list = AST::ListNode.new(list_type: :dl)

    # First definition item: : Alpha \n    RISC CPU made by DEC.
    item1 = AST::ListItemNode.new(content: 'Alpha', level: 1)
    # Set term as term_children (not regular children)
    term1 = AST::TextNode.new(content: 'Alpha')
    item1.term_children = [term1]
    # Add definition as regular child
    def1 = AST::TextNode.new(content: 'RISC CPU made by DEC.')
    item1.add_child(def1)

    # Second definition item with brackets in term
    item2 = AST::ListItemNode.new(content: 'POWER [IBM]', level: 1)
    term2 = AST::TextNode.new(content: 'POWER [IBM]')
    item2.term_children = [term2]
    def2 = AST::TextNode.new(content: 'RISC CPU made by IBM and Motorola.')
    item2.add_child(def2)

    list.add_child(item1)
    list.add_child(item2)

    result = @renderer.visit(list)

    expected = "\n\\begin{description}\n" +
               "\\item[Alpha] \\mbox{} \\\\\n" +
               "RISC CPU made by DEC.\n" +
               "\\item[POWER \\lbrack{}IBM\\rbrack{}] \\mbox{} \\\\\n" +
               "RISC CPU made by IBM and Motorola.\n" +
               "\\end{description}\n"

    assert_equal expected, result
  end

  def test_visit_list_definition_single_child
    # Test definition list with term only (no definition)
    list = AST::ListNode.new(list_type: :dl)

    item = AST::ListItemNode.new(content: 'Term Only', level: 1)
    # Set term as term_children, no regular children (no definition)
    term = AST::TextNode.new(content: 'Term Only')
    item.term_children = [term]

    list.add_child(item)

    result = @renderer.visit(list)

    expected = "\n\\begin{description}\n" +
               "\\item[Term Only] \\mbox{} \\\\\n" +
               "\\end{description}\n"

    assert_equal expected, result
  end
end
