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
    @config = ReVIEW::Configure.values
    @config['builder'] = 'latex' # Set builder for tsize processing
    @book = ReVIEW::Book::Base.new(config: @config)
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
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Chapter Title'))

    headline = AST::HeadlineNode.new(level: 1, caption: 'Chapter Title', caption_node: caption_node, label: 'chap1')
    result = @renderer.visit(headline)

    assert_equal "\\chapter{Chapter Title}\n\\label{chap:test}\n\n", result
  end

  def test_visit_headline_level2
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: 'Section Title', caption_node: caption_node)
    result = @renderer.visit(headline)

    assert_equal "\\section{Section Title}\n\\label{sec:1-1}\n\n", result
  end

  def test_visit_headline_with_secnolevel_default
    # Default secnolevel is 2, so level 3 should be subsection*
    @config['secnolevel'] = 2
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Subsection Title'))

    headline = AST::HeadlineNode.new(level: 3, caption: 'Subsection Title', caption_node: caption_node)
    result = @renderer.visit(headline)

    expected = "\\subsection*{Subsection Title}\n\\addcontentsline{toc}{subsection}{Subsection Title}\n\\label{sec:1-0-1}\n\n"
    assert_equal expected, result
  end

  def test_visit_headline_with_secnolevel3
    # secnolevel 3, so level 3 should be normal subsection, level 4 should be subsubsection*
    @config['secnolevel'] = 3

    # Level 3 - normal subsection
    caption_node3 = AST::CaptionNode.new
    caption_node3.add_child(AST::TextNode.new(content: 'Subsection Title'))
    headline3 = AST::HeadlineNode.new(level: 3, caption: 'Subsection Title', caption_node: caption_node3)
    result3 = @renderer.visit(headline3)
    assert_equal "\\subsection{Subsection Title}\n\\label{sec:1-0-1}\n\n", result3

    # Level 4 - subsubsection* without addcontentsline (exceeds default toclevel of 3)
    caption_node4 = AST::CaptionNode.new
    caption_node4.add_child(AST::TextNode.new(content: 'Subsubsection Title'))
    headline4 = AST::HeadlineNode.new(level: 4, caption: 'Subsubsection Title', caption_node: caption_node4)
    result4 = @renderer.visit(headline4)
    expected4 = "\\subsubsection*{Subsubsection Title}\n\\label{sec:1-0-1-1}\n\n"
    assert_equal expected4, result4
  end

  def test_visit_headline_with_secnolevel1
    # secnolevel 1, so level 2 and above should be section*
    @config['secnolevel'] = 1
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: 'Section Title', caption_node: caption_node)
    result = @renderer.visit(headline)

    expected = "\\section*{Section Title}\n\\addcontentsline{toc}{section}{Section Title}\n\\label{sec:1-1}\n\n"
    assert_equal expected, result
  end

  def test_visit_headline_numberless_chapter
    # Numberless chapter: level > 1 should get star commands
    @chapter.instance_variable_set(:@number, '') # Make chapter numberless
    @config['secnolevel'] = 3

    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: 'Section Title', caption_node: caption_node)
    result = @renderer.visit(headline)

    expected = "\\section*{Section Title}\n\\addcontentsline{toc}{section}{Section Title}\n\\label{sec:-1}\n\n"
    assert_equal expected, result
  end

  def test_visit_headline_secnolevel0
    # secnolevel 0 means all levels should be starred
    @config['secnolevel'] = 0

    # Level 1 - chapter*
    caption_node1 = AST::CaptionNode.new
    caption_node1.add_child(AST::TextNode.new(content: 'Chapter Title'))
    headline1 = AST::HeadlineNode.new(level: 1, caption: 'Chapter Title', caption_node: caption_node1)
    result1 = @renderer.visit(headline1)
    expected1 = "\\chapter*{Chapter Title}\n\\addcontentsline{toc}{chapter}{Chapter Title}\n\\label{chap:test}\n\n"
    assert_equal expected1, result1

    # Level 2 - section*
    caption_node2 = AST::CaptionNode.new
    caption_node2.add_child(AST::TextNode.new(content: 'Section Title'))
    headline2 = AST::HeadlineNode.new(level: 2, caption: 'Section Title', caption_node: caption_node2)
    result2 = @renderer.visit(headline2)
    expected2 = "\\section*{Section Title}\n\\addcontentsline{toc}{section}{Section Title}\n\\label{sec:1-1}\n\n"
    assert_equal expected2, result2
  end

  def test_visit_headline_part_level1
    # Test Part with level 1 - should use \part command
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Part Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: 'Part Title', caption_node: caption_node)
    result = part_renderer.visit(headline)

    expected = "\\begin{reviewpart}\n\\part{Part Title}\n\\label{chap:part1}\n\n"
    assert_equal expected, result
  end

  def test_visit_headline_part_with_secnolevel0
    # Test Part with secnolevel 0 - should use \part* command
    @config['secnolevel'] = 0
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Part Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: 'Part Title', caption_node: caption_node)
    result = part_renderer.visit(headline)

    expected = "\\begin{reviewpart}\n\\part*{Part Title}\n\\addcontentsline{toc}{part}{Part Title}\n\\label{chap:part1}\n\n"
    assert_equal expected, result
  end

  def test_visit_headline_part_level2
    # Test Part with level 2 - should use normal chapter/section commands
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Chapter in Part'))
    headline = AST::HeadlineNode.new(level: 2, caption: 'Chapter in Part', caption_node: caption_node)
    result = part_renderer.visit(headline)

    expected = "\\section{Chapter in Part}\n\\label{sec:1-1}\n\n"
    assert_equal expected, result
  end

  def test_visit_headline_numberless_part
    # Test numberless Part - level > 1 should get star commands
    @config['secnolevel'] = 3
    part = ReVIEW::Book::Part.new(@book, '', 'partx', 'partx.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Chapter in Numberless Part'))
    headline = AST::HeadlineNode.new(level: 2, caption: 'Chapter in Numberless Part', caption_node: caption_node)
    result = part_renderer.visit(headline)

    expected = "\\section*{Chapter in Numberless Part}\n\\addcontentsline{toc}{section}{Chapter in Numberless Part}\n\\label{sec:-1}\n\n"
    assert_equal expected, result
  end

  def test_visit_inline_bold
    inline = AST::InlineNode.new(inline_type: :b)
    inline.add_child(AST::TextNode.new(content: 'bold text'))

    result = @renderer.visit(inline)
    assert_equal '\\reviewbold{bold text}', result
  end

  def test_visit_inline_italic
    inline = AST::InlineNode.new(inline_type: :i)
    inline.add_child(AST::TextNode.new(content: 'italic text'))

    result = @renderer.visit(inline)
    assert_equal '\\reviewit{italic text}', result
  end

  def test_visit_inline_code
    inline = AST::InlineNode.new(inline_type: :tt)
    inline.add_child(AST::TextNode.new(content: 'code text'))

    result = @renderer.visit(inline)
    assert_equal '\\reviewtt{code text}', result
  end

  def test_visit_inline_footnote
    inline = AST::InlineNode.new(inline_type: :fn, args: ['footnote1'])

    result = @renderer.visit(inline)
    assert_equal '\\footnote{footnote1}', result
  end

  def test_visit_code_block_with_caption
    caption = 'Code Example'
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: caption))

    code_block = AST::CodeBlockNode.new(caption: caption, caption_node: caption_node, code_type: 'emlist')
    line1 = AST::CodeLineNode.new(location: nil)
    line1.add_child(AST::TextNode.new(content: 'puts "Hello"'))
    code_block.add_child(line1)

    result = @renderer.visit(code_block)
    expected = "\\begin{reviewlistblock}\n" +
               "\\reviewemlistcaption{Code Example}\n" +
               "\\begin{reviewemlist}\n" +
               "puts \"Hello\"\n" +
               "\\end{reviewemlist}\n" +
               "\\end{reviewlistblock}\n\n"

    assert_equal expected, result
  end

  def test_visit_table
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Test Table'))

    table = AST::TableNode.new(id: 'table1', caption_node: caption_node)

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

    assert_equal expected_lines.join("\n") + "\n\n", result
  end

  def test_visit_image
    # Test for missing image (no image file bound to chapter)
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Test Image'))

    image = AST::ImageNode.new(id: 'image1', caption: 'Test Image', caption_node: caption_node)
    result = @renderer.visit(image)

    expected_lines = [
      '\\begin{reviewdummyimage}',
      '{-}{-}[[path = image1 (not exist)]]{-}{-}',
      '\\label{image:test:image1}',
      '\\reviewimagecaption{Test Image}',
      '\\end{reviewdummyimage}'
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
    expected = "\n\\begin{itemize}\n\\item First item\n\\item Second item\n\\end{itemize}\n\n"

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
    expected = "\n\\begin{enumerate}\n\\item First item\n\\item Second item\n\\end{enumerate}\n\n"

    assert_equal expected, result
  end

  def test_visit_minicolumn_note
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Note Caption'))

    minicolumn = AST::MinicolumnNode.new(minicolumn_type: :note, caption: 'Note Caption', caption_node: caption_node)
    minicolumn.add_child(AST::TextNode.new(content: 'This is a note.'))

    result = @renderer.visit(minicolumn)
    expected = "\\begin{reviewnote}[Note Caption]\n\nThis is a note.\n\\end{reviewnote}\n\n"

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
    inline = AST::InlineNode.new(inline_type: :href, args: ['http://example.com', 'Example'])

    result = @renderer.visit(inline)
    assert_equal '\\href{http://example.com}{Example}', result
  end

  def test_render_inline_element_href_internal_reference_with_label
    inline = AST::InlineNode.new(inline_type: :href, args: ['#anchor', 'Jump to anchor'])

    result = @renderer.visit(inline)
    assert_equal '\\hyperref[anchor]{Jump to anchor}', result
  end

  def test_render_inline_element_href_internal_reference_without_label
    inline = AST::InlineNode.new(inline_type: :href, args: ['#anchor'])
    inline.add_child(AST::TextNode.new(content: '#anchor'))

    result = @renderer.visit(inline)
    assert_equal '\\hyperref[anchor]{\\#anchor}', result
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
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Part Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: 'Part Title', caption_node: caption_node)
    document.add_child(headline)

    # Add a paragraph
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'Part content here.'))
    document.add_child(paragraph)

    result = part_renderer.visit(document)

    expected = "\\begin{reviewpart}\n" +
               "\\part{Part Title}\n" +
               "\\label{chap:part1}\n\n" +
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
    caption_node1 = AST::CaptionNode.new
    caption_node1.add_child(AST::TextNode.new(content: 'Part Title'))
    headline1 = AST::HeadlineNode.new(level: 1, caption: 'Part Title', caption_node: caption_node1)
    document.add_child(headline1)

    # Add second level 1 headline (should not open reviewpart again)
    caption_node2 = AST::CaptionNode.new
    caption_node2.add_child(AST::TextNode.new(content: 'Another Part Title'))
    headline2 = AST::HeadlineNode.new(level: 1, caption: 'Another Part Title', caption_node: caption_node2)
    document.add_child(headline2)

    result = part_renderer.visit(document)

    expected = "\\begin{reviewpart}\n" +
               "\\part{Part Title}\n" +
               "\\label{chap:part1}\n\n" +
               "\\part{Another Part Title}\n" +
               "\\label{chap:part1}\n\n" +
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
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Section Title'))
    headline = AST::HeadlineNode.new(level: 2, caption: 'Section Title', caption_node: caption_node)
    document.add_child(headline)

    result = part_renderer.visit(document)

    expected = "\\section{Section Title}\n" +
               "\\label{sec:1-1}\n\n"

    assert_equal expected, result
  end

  def test_visit_chapter_document_no_reviewpart
    # Test that regular Chapter documents do not get reviewpart environment
    document = AST::DocumentNode.new

    # Add level 1 headline
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Chapter Title'))
    headline = AST::HeadlineNode.new(level: 1, caption: 'Chapter Title', caption_node: caption_node)
    document.add_child(headline)

    # Add a paragraph
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'Chapter content here.'))
    document.add_child(paragraph)

    result = @renderer.visit(document)

    expected = "\\chapter{Chapter Title}\n" +
               "\\label{chap:test}\n\n" +
               "Chapter content here.\n\n"

    assert_equal expected, result
  end

  def test_visit_headline_nonum
    # Test [nonum] option - unnumbered section with TOC entry
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Unnumbered Section'))

    headline = AST::HeadlineNode.new(level: 2, caption: 'Unnumbered Section', caption_node: caption_node, tag: 'nonum')
    result = @renderer.visit(headline)

    # nonum does NOT get labels (matching LATEXBuilder behavior)
    expected = "\\section*{Unnumbered Section}\n" +
               "\\addcontentsline{toc}{section}{Unnumbered Section}\n\n"

    assert_equal expected, result
  end

  def test_visit_headline_notoc
    # Test [notoc] option - unnumbered section without TOC entry
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'No TOC Section'))

    headline = AST::HeadlineNode.new(level: 2, caption: 'No TOC Section', caption_node: caption_node, tag: 'notoc')
    result = @renderer.visit(headline)

    # notoc does NOT get labels (matching LATEXBuilder behavior)
    expected = "\\section*{No TOC Section}\n\n"

    assert_equal expected, result
  end

  def test_visit_headline_nodisp
    # Test [nodisp] option - TOC entry only, no visible heading
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Hidden Section'))

    headline = AST::HeadlineNode.new(level: 2, caption: 'Hidden Section', caption_node: caption_node, tag: 'nodisp')
    result = @renderer.visit(headline)

    expected = "\\addcontentsline{toc}{section}{Hidden Section}\n"

    assert_equal expected, result
  end

  def test_visit_headline_nonum_level1
    # Test [nonum] option for level 1 (chapter)
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Unnumbered Chapter'))

    headline = AST::HeadlineNode.new(level: 1, caption: 'Unnumbered Chapter', caption_node: caption_node, tag: 'nonum')
    result = @renderer.visit(headline)

    # nonum does NOT get labels (matching LATEXBuilder behavior)
    expected = "\\chapter*{Unnumbered Chapter}\n" +
               "\\addcontentsline{toc}{chapter}{Unnumbered Chapter}\n\n"

    assert_equal expected, result
  end

  def test_visit_headline_nonum_level3
    # Test [nonum] option for level 3 (subsection)
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Unnumbered Subsection'))

    headline = AST::HeadlineNode.new(level: 3, caption: 'Unnumbered Subsection', caption_node: caption_node, tag: 'nonum')
    result = @renderer.visit(headline)

    # nonum does NOT get labels (matching LATEXBuilder behavior)
    expected = "\\subsection*{Unnumbered Subsection}\n" +
               "\\addcontentsline{toc}{subsection}{Unnumbered Subsection}\n\n"

    assert_equal expected, result
  end

  def test_visit_headline_part_nonum
    # Test [nonum] option for Part level 1
    part = ReVIEW::Book::Part.new(@book, 1, 'part1', 'part1.re', StringIO.new)
    part.generate_indexes
    part_renderer = Renderer::LatexRenderer.new(part)

    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Unnumbered Part'))
    headline = AST::HeadlineNode.new(level: 1, caption: 'Unnumbered Part', caption_node: caption_node, tag: 'nonum')
    result = part_renderer.visit(headline)

    # Part level 1 with nonum does NOT get a label (matching LATEXBuilder behavior)
    expected = "\\begin{reviewpart}\n" +
               "\\part*{Unnumbered Part}\n" +
               "\\addcontentsline{toc}{chapter}{Unnumbered Part}\n\n"

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
    inline_node = AST::InlineNode.new(inline_type: :b)
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
    caption = 'Test Column'
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: caption))

    column = AST::ColumnNode.new(level: 3, caption: caption, caption_node: caption_node, column_type: :column, auto_id: 'column-1', column_number: 1)
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
               "\\end{reviewcolumn}\n" +
               "\n"

    assert_equal expected, result
  end

  def test_visit_column_no_caption
    # Test column without caption
    column = AST::ColumnNode.new(level: 3, column_type: :column, auto_id: 'column-1', column_number: 1)
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'No caption column.'))
    column.add_child(paragraph)

    result = @renderer.visit(column)

    expected = "\n" +
               "\\begin{reviewcolumn}[\\hypertarget{column:test:1}{}]\n" +
               "\n" +
               "No caption column.\n\n" +
               "\\end{reviewcolumn}\n" +
               "\n"

    assert_equal expected, result
  end

  def test_visit_column_toclevel_filter
    # Test column TOC entry based on toclevel setting
    @config['toclevel'] = 2 # Only levels 1-2 should get TOC entries

    caption = 'Level 3 Column'
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: caption))

    column = AST::ColumnNode.new(level: 3, caption: caption, caption_node: caption_node, column_type: :column, auto_id: 'column-1', column_number: 1)
    paragraph = AST::ParagraphNode.new
    paragraph.add_child(AST::TextNode.new(content: 'This should not get TOC entry.'))
    column.add_child(paragraph)

    result = @renderer.visit(column)

    # Should not contain addcontentsline since level 3 > toclevel 2
    expected = "\n" +
               "\\begin{reviewcolumn}[Level 3 Column\\hypertarget{column:test:1}{}]\n" +
               "\n" +
               "This should not get TOC entry.\n\n" +
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
    # Set term as term_children (not regular children)
    term1 = AST::TextNode.new(content: 'Alpha')
    item1 = AST::ListItemNode.new(content: 'Alpha', level: 1, term_children: [term1])
    # Add definition as regular child
    def1 = AST::TextNode.new(content: 'RISC CPU made by DEC.')
    item1.add_child(def1)

    # Second definition item with brackets in term
    term2 = AST::TextNode.new(content: 'POWER [IBM]')
    item2 = AST::ListItemNode.new(content: 'POWER [IBM]', level: 1, term_children: [term2])
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
               "\\end{description}\n\n"

    assert_equal expected, result
  end

  def test_visit_list_definition_single_child
    # Test definition list with term only (no definition)
    list = AST::ListNode.new(list_type: :dl)

    # Set term as term_children, no regular children (no definition)
    term = AST::TextNode.new(content: 'Term Only')
    item = AST::ListItemNode.new(content: 'Term Only', level: 1, term_children: [term])

    list.add_child(item)

    result = @renderer.visit(list)

    expected = "\n\\begin{description}\n" +
               "\\item[Term Only] \\mbox{} \\\\\n" +
               "\\end{description}\n\n"

    assert_equal expected, result
  end

  def test_footnote_with_inline_markup
    # Test that footnote content with inline markup is properly rendered
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][This is a footnote with @<b>{bold}, @<i>{italic}, and @<code>{code}]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    # Check that inline markup in footnote is properly rendered
    assert_match(/\\footnote\{This is a footnote with \\reviewbold\{bold\}, \\reviewit\{italic\}, and \\reviewcode\{code\}\}/, result)
  end

  def test_footnote_with_bold_markup
    # Test footnote with bold text
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][Footnote with @<b>{bold text}]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    assert_match(/\\footnote\{Footnote with \\reviewbold\{bold text\}\}/, result)
  end

  def test_footnote_with_italic_markup
    # Test footnote with italic text
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][Footnote with @<i>{italic text}]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    assert_match(/\\footnote\{Footnote with \\reviewit\{italic text\}\}/, result)
  end

  def test_footnote_with_code_markup
    # Test footnote with code text
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][Footnote with @<code>{code_example}]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    # NOTE: underscore is escaped as \textunderscore{} in LaTeX
    assert_match(/\\footnote\{Footnote with \\reviewcode\{code(\\textunderscore\{\}|_)example\}\}/, result)
  end

  def test_footnote_with_href_markup
    # Test footnote with hyperlink
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][See @<href>{http://example.com, Example Site}]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    assert_match(%r{\\footnote\{See \\href\{http://example\.com\}\{Example Site\}\}}, result)
  end

  def test_footnote_with_multiple_inline_elements
    # Test footnote with multiple types of inline markup
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][This has @<b>{bold}, @<i>{italic}, @<tt>{typewriter}, and @<code>{code}]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    assert_match(/\\reviewbold\{bold\}/, result)
    assert_match(/\\reviewit\{italic\}/, result)
    assert_match(/\\reviewtt\{typewriter\}/, result)
    assert_match(/\\reviewcode\{code\}/, result)
  end

  def test_footnote_plain_text
    # Test footnote with plain text (no inline markup)
    content = <<~EOB
      = Test Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][This is a plain footnote]
    EOB

    @chapter.content = content
    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(@chapter)

    renderer = Renderer::LatexRenderer.new(@chapter)
    result = renderer.visit(ast_root)

    assert_match(/\\footnote\{This is a plain footnote\}/, result)
  end

  # Tests for parse_metric method
  def test_parse_metric_latex_prefix
    # Test parsing metric with latex:: prefix
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_parse_metric_no_prefix
    # Test parsing metric without prefix
    result = @renderer.send(:parse_metric, 'latex', 'width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_parse_metric_multiple_values
    # Test parsing metric with multiple comma-separated values
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm,height=60mm')
    assert_equal 'width=80mm,height=60mm', result
  end

  def test_parse_metric_mixed_prefix
    # Test parsing metric with mixed prefix and non-prefix values
    result = @renderer.send(:parse_metric, 'latex', 'latex::width=80mm,height=60mm')
    assert_equal 'width=80mm,height=60mm', result
  end

  def test_parse_metric_wrong_prefix
    # Test parsing metric with wrong builder prefix (should be ignored)
    result = @renderer.send(:parse_metric, 'latex', 'html::width=80mm')
    assert_equal '', result
  end

  def test_parse_metric_multiple_prefixes
    # Test parsing metric with multiple builder prefixes
    result = @renderer.send(:parse_metric, 'latex', 'html::width=100px,latex::width=80mm')
    assert_equal 'width=80mm', result
  end

  def test_parse_metric_nil
    # Test parsing nil metric
    result = @renderer.send(:parse_metric, 'latex', nil)
    assert_equal '', result
  end

  def test_parse_metric_empty
    # Test parsing empty metric
    result = @renderer.send(:parse_metric, 'latex', '')
    assert_equal '', result
  end

  def test_parse_metric_scale_conversion
    # Test scale to width conversion when image_scale2width is enabled
    @config['pdfmaker'] = { 'image_scale2width' => true }
    result = @renderer.send(:parse_metric, 'latex', 'scale=0.5')
    assert_equal 'width=0.5\\maxwidth', result
  end

  def test_parse_metric_scale_no_conversion
    # Test scale without conversion when image_scale2width is disabled
    @config['pdfmaker'] = {}
    result = @renderer.send(:parse_metric, 'latex', 'scale=0.5')
    assert_equal 'scale=0.5', result
  end

  def test_parse_metric_use_original_image_size
    # Test use_original_image_size config
    @config['pdfmaker'] = { 'use_original_image_size' => true }
    result = @renderer.send(:parse_metric, 'latex', nil)
    assert_equal ' ', result # Should return space to use original size
  end

  def test_parse_metric_use_original_image_size_with_metric
    # Test use_original_image_size config with metric provided (should use provided metric)
    @config['pdfmaker'] = { 'use_original_image_size' => true }
    result = @renderer.send(:parse_metric, 'latex', 'width=80mm')
    assert_equal 'width=80mm', result
  end

  # Integration test for image with metric (missing image case)
  def test_visit_image_with_metric
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Test Image'))

    # Create an image node with metric (image doesn't exist)
    image = AST::ImageNode.new(id: 'image1', caption: 'Test Image', caption_node: caption_node, metric: 'latex::width=80mm')
    result = @renderer.visit(image)

    expected_lines = [
      '\\begin{reviewdummyimage}',
      '{-}{-}[[path = image1 (not exist)]]{-}{-}',
      '\\label{image:test:image1}',
      '\\reviewimagecaption{Test Image}',
      '\\end{reviewdummyimage}'
    ]

    assert_equal expected_lines.join("\n") + "\n", result
  end

  def test_visit_table_without_caption
    # Test table without caption (should not output \begin{table} and \end{table})
    table = AST::TableNode.new(id: 'table1')

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

    # Should not contain \begin{table} and \end{table} without caption
    assert_false(result.include?('\\begin{table}'), 'Should not include \\begin{table} without caption')
    assert_false(result.include?('\\end{table}'), 'Should not include \\end{table} without caption')

    # Should contain table structure with label (label is output regardless of caption)
    expected_lines = [
      '\\label{table:test:table1}',
      '\\begin{reviewtable}{|l|l|}',
      '\\hline',
      '\\reviewth{Header 1} & \\reviewth{Header 2} \\\\  \\hline',
      'Data 1 & Data 2 \\\\  \\hline',
      '\\end{reviewtable}'
    ]

    assert_equal expected_lines.join("\n") + "\n\n", result
  end

  def test_visit_table_with_empty_caption_node
    # Test table with empty caption node (should not output \begin{table} and \end{table})
    empty_caption_node = AST::CaptionNode.new
    # Empty caption node with no children

    table = AST::TableNode.new(id: 'table1', caption_node: empty_caption_node)

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

    # Empty caption should be treated as no caption (should not output \begin{table} and \end{table})
    assert_false(result.include?('\\begin{table}'), 'Should not include \\begin{table} with empty caption')
    assert_false(result.include?('\\end{table}'), 'Should not include \\end{table} with empty caption')

    # Should contain table structure with label
    expected_lines = [
      '\\label{table:test:table1}',
      '\\begin{reviewtable}{|l|l|}',
      '\\hline',
      '\\reviewth{Header 1} & \\reviewth{Header 2} \\\\  \\hline',
      'Data 1 & Data 2 \\\\  \\hline',
      '\\end{reviewtable}'
    ]

    assert_equal expected_lines.join("\n") + "\n\n", result
  end

  def test_inline_bib_reference
    # Test @<bib> inline reference
    # Setup a bibpaper index
    bibpaper_index = ReVIEW::Book::BibpaperIndex.new
    item = ReVIEW::Book::Index::Item.new('lins', 1, 'Lins, 1992')
    bibpaper_index.add_item(item)
    @book.bibpaper_index = bibpaper_index

    inline = AST::InlineNode.new(inline_type: :bib, args: ['lins'])
    result = @renderer.visit(inline)
    assert_equal '\\reviewbibref{[1]}{bib:lins}', result
  end

  def test_inline_bib_reference_multiple
    # Test @<bib> with multiple bibliography entries
    bibpaper_index = ReVIEW::Book::BibpaperIndex.new
    item1 = ReVIEW::Book::Index::Item.new('lins', 1, 'Lins, 1992')
    item2 = ReVIEW::Book::Index::Item.new('knuth', 2, 'Knuth, 1997')
    bibpaper_index.add_item(item1)
    bibpaper_index.add_item(item2)
    @book.bibpaper_index = bibpaper_index

    inline1 = AST::InlineNode.new(inline_type: :bib, args: ['lins'])
    result1 = @renderer.visit(inline1)
    assert_equal '\\reviewbibref{[1]}{bib:lins}', result1

    inline2 = AST::InlineNode.new(inline_type: :bib, args: ['knuth'])
    result2 = @renderer.visit(inline2)
    assert_equal '\\reviewbibref{[2]}{bib:knuth}', result2
  end

  def test_inline_bibref_alias
    # Test @<bibref> (alias for @<bib>)
    bibpaper_index = ReVIEW::Book::BibpaperIndex.new
    item = ReVIEW::Book::Index::Item.new('lins', 1, 'Lins, 1992')
    bibpaper_index.add_item(item)
    @book.bibpaper_index = bibpaper_index

    inline = AST::InlineNode.new(inline_type: :bibref, args: ['lins'])
    result = @renderer.visit(inline)
    assert_equal '\\reviewbibref{[1]}{bib:lins}', result
  end

  def test_inline_bib_no_index
    # Test @<bib> when there's no bibpaper_index (should fallback to \cite)
    @book.bibpaper_index = nil

    inline = AST::InlineNode.new(inline_type: :bib, args: ['lins'])
    result = @renderer.visit(inline)
    assert_equal '\\cite{lins}', result
  end

  def test_inline_bib_not_found_in_index
    # Test @<bib> when the ID is not found in index (should fallback to \cite)
    bibpaper_index = ReVIEW::Book::BibpaperIndex.new
    item = ReVIEW::Book::Index::Item.new('knuth', 1, 'Knuth, 1997')
    bibpaper_index.add_item(item)
    @book.bibpaper_index = bibpaper_index

    inline = AST::InlineNode.new(inline_type: :bib, args: ['lins'])
    result = @renderer.visit(inline)
    # Should fallback to \cite when not found
    assert_equal '\\cite{lins}', result
  end

  def test_inline_idx_simple
    # Test @<idx>{term} - simple index entry
    inline = AST::InlineNode.new(inline_type: :idx, args: ['keyword'])
    inline.add_child(AST::TextNode.new(content: 'keyword'))
    result = @renderer.visit(inline)
    assert_equal 'keyword\\index{keyword}', result
  end

  def test_inline_idx_hierarchical
    # Test @<idx>{親項目<<>>子項目} - hierarchical index entry
    inline = AST::InlineNode.new(inline_type: :idx, args: ['親項目<<>>子項目'])
    inline.add_child(AST::TextNode.new(content: '子項目'))
    result = @renderer.visit(inline)
    # Should process hierarchical index: split by <<>>, escape, and join with !
    # Japanese text should get yomi conversion
    assert_match(/子項目\\index\{.+!.+\}/, result)
  end

  def test_inline_idx_ascii
    # Test @<idx>{term} with ASCII characters
    inline = AST::InlineNode.new(inline_type: :idx, args: ['Ruby'])
    inline.add_child(AST::TextNode.new(content: 'Ruby'))
    result = @renderer.visit(inline)
    assert_equal 'Ruby\\index{Ruby}', result
  end

  def test_inline_hidx_simple
    # Test @<hidx>{term} - hidden index entry
    inline = AST::InlineNode.new(inline_type: :hidx, args: ['keyword'])
    result = @renderer.visit(inline)
    assert_equal '\\index{keyword}', result
  end

  def test_inline_hidx_hierarchical
    # Test @<hidx>{索引<<>>idx} - hierarchical hidden index entry
    inline = AST::InlineNode.new(inline_type: :hidx, args: ['索引<<>>idx'])
    result = @renderer.visit(inline)
    # Should process hierarchical index: split by <<>>, escape, and join with !
    # Japanese text should get yomi conversion, ASCII should not
    assert_match(/\\index\{.+!idx\}/, result)
  end

  def test_inline_idx_with_special_chars
    # Test @<idx> with special characters that need escaping
    inline = AST::InlineNode.new(inline_type: :idx, args: ['term@example'])
    inline.add_child(AST::TextNode.new(content: 'term@example'))
    result = @renderer.visit(inline)
    # @ should be escaped as "@ by escape_index
    # Format: key@display where key is used for sorting, display is shown
    # Both key and display should have @ escaped
    assert_match(/term@example\\index\{term"@example@term"@example\}/, result)
  end

  def test_inline_column_same_chapter
    # Test @<column>{column1} - same-chapter column reference
    # Setup: add a column to the current chapter's column_index
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Test Column'))
    column_item = ReVIEW::Book::Index::Item.new('column1', 1, 'Test Column', caption_node: caption_node)
    @chapter.column_index.add_item(column_item)

    inline = AST::InlineNode.new(inline_type: :column, args: ['column1'])
    result = @renderer.visit(inline)

    # Should generate \reviewcolumnref with column text and label
    assert_match(/\\reviewcolumnref\{/, result)
    assert_match(/column:test:1/, result) # Label format: column:chapter_id:number
  end

  def test_inline_column_cross_chapter
    # Test @<column>{ch03|column2} - cross-chapter column reference
    # This tests the fix for the issue where args = ["ch03", "column2"]

    # Create another chapter (ch03) and add it to the book via parts
    ch03 = ReVIEW::Book::Chapter.new(@book, 3, 'ch03', 'ch03.re', StringIO.new)
    ch03.generate_indexes

    # Create a part and add both chapters to it
    part = ReVIEW::Book::Part.new(@book, 1, [@chapter, ch03])
    @book.instance_variable_set(:@parts, [part])

    # Add a column to ch03's column_index
    caption_node = AST::CaptionNode.new
    caption_node.add_child(AST::TextNode.new(content: 'Column in Ch03'))
    column_item = ReVIEW::Book::Index::Item.new('column2', 1, 'Column in Ch03', caption_node: caption_node)
    ch03.column_index.add_item(column_item)

    # Create inline node with args as 2-element array (as AST parser does)
    inline = AST::InlineNode.new(inline_type: :column, args: ['ch03', 'column2'])
    result = @renderer.visit(inline)

    # Should generate \reviewcolumnref with column text and label from ch03
    assert_match(/\\reviewcolumnref\{/, result)
    assert_match(/column:ch03:1/, result) # Label format: column:ch03:number
    assert_match(/Column in Ch03/, result) # Should include caption
  end

  def test_inline_column_cross_chapter_not_found
    # Test @<column>{ch99|column1} - reference to non-existent chapter
    # Should raise NotImplementedError

    inline = AST::InlineNode.new(inline_type: :column, args: ['ch99', 'column1'])

    assert_raise(NotImplementedError) do
      @renderer.visit(inline)
    end
  end
end
