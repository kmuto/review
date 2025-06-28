# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require File.expand_path('test_helper', __dir__)
require 'review/renderer/latex_renderer'
require 'review/ast'
require 'review/book'
require 'review/book/chapter'

class TestLATEXRenderer < Test::Unit::TestCase
  include ReVIEW

  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @book.config = @config
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    @chapter.generate_indexes
    @book.generate_indexes

    @renderer = Renderer::LATEXRenderer.new(@chapter)
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

  def test_visit_headline_level_1
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Chapter Title'))

    headline = AST::HeadlineNode.new(level: 1, caption: caption, label: 'chap1')
    result = @renderer.visit(headline)

    assert_equal "\\chapter{Chapter Title}\n\\label{chap:test}\n", result
  end

  def test_visit_headline_level_2
    caption = AST::CaptionNode.new
    caption.add_child(AST::TextNode.new(content: 'Section Title'))

    headline = AST::HeadlineNode.new(level: 2, caption: caption)
    result = @renderer.visit(headline)

    assert_equal "\\section{Section Title}\n\\label{sec:1-1}\n", result
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
               "\n" +
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
    # Create an unknown node type by using a generic Node
    unknown_node = AST::Node.new(type: 'UnknownNode')

    assert_raise(NotImplementedError) do
      @renderer.visit(unknown_node)
    end
  end
end
