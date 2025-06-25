# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/review_generator'
require 'review/ast/code_line_node'
require 'review/ast/table_row_node'
require 'review/ast/table_cell_node'

class TestASTReVIEWGenerator < Test::Unit::TestCase
  def setup
    @generator = ReVIEW::AST::ReVIEWGenerator.new
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_empty_document
    doc = ReVIEW::AST::DocumentNode.new
    result = @generator.generate(doc)
    assert_equal '', result
  end

  def test_headline
    doc = ReVIEW::AST::DocumentNode.new
    headline = ReVIEW::AST::HeadlineNode.new(
      level: 2,
      label: 'intro',
      caption: 'Introduction'
    )
    doc.add_child(headline)

    result = @generator.generate(doc)
    assert_equal "==[intro] Introduction\n\n", result
  end

  def test_paragraph_with_text
    doc = ReVIEW::AST::DocumentNode.new
    para = ReVIEW::AST::ParagraphNode.new
    para.add_child(ReVIEW::AST::TextNode.new(content: 'Hello, world!'))
    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "Hello, world!\n\n", result
  end

  def test_inline_elements
    doc = ReVIEW::AST::DocumentNode.new
    para = ReVIEW::AST::ParagraphNode.new

    para.add_child(ReVIEW::AST::TextNode.new(content: 'This is '))

    bold = ReVIEW::AST::InlineNode.new(inline_type: 'b')
    bold.add_child(ReVIEW::AST::TextNode.new(content: 'bold'))
    para.add_child(bold)

    para.add_child(ReVIEW::AST::TextNode.new(content: ' text.'))
    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "This is @<b>{bold} text.\n\n", result
  end

  def test_code_block_with_id
    doc = ReVIEW::AST::DocumentNode.new

    # Create caption node
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello Example'))

    code = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'hello',
      caption: caption,
      original_text: "def hello\n  puts \"Hello\"\nend",
      lang: 'ruby'
    )

    # Add code line nodes
    ['def hello', '  puts "Hello"', 'end'].each do |line|
      line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
      line_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: line))
      code.add_child(line_node)
    end

    doc.add_child(code)

    result = @generator.generate(doc)
    expected = <<~EOB
      //list[hello][Hello Example]{
      def hello
        puts "Hello"
      end
      //}

    EOB
    assert_equal expected, result
  end

  def test_code_block_without_id
    doc = ReVIEW::AST::DocumentNode.new
    code = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'echo "Hello"',
      lang: 'sh'
    )

    # Add code line node
    line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
    line_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'echo "Hello"'))
    code.add_child(line_node)

    doc.add_child(code)

    result = @generator.generate(doc)
    expected = <<~EOB
      //emlist{
      echo "Hello"
      //}

    EOB
    assert_equal expected, result
  end

  def test_unordered_list
    doc = ReVIEW::AST::DocumentNode.new
    list = ReVIEW::AST::ListNode.new(list_type: :ul)

    item1 = ReVIEW::AST::ListItemNode.new(level: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(content: 'First item'))
    list.add_child(item1)

    item2 = ReVIEW::AST::ListItemNode.new(level: 1)
    item2.add_child(ReVIEW::AST::TextNode.new(content: 'Second item'))
    list.add_child(item2)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = <<~EOB
      * First item
      * Second item

    EOB
    assert_equal expected, result
  end

  def test_table
    doc = ReVIEW::AST::DocumentNode.new

    # Create caption node
    caption = ReVIEW::AST::CaptionNode.new(location: @location)
    caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Sample Table'))

    table = ReVIEW::AST::TableNode.new(
      location: @location,
      id: 'sample',
      caption: caption
    )

    # Add header row
    header_row = ReVIEW::AST::TableRowNode.new(location: @location)
    ['Name', 'Age'].each do |cell_content|
      cell = ReVIEW::AST::TableCellNode.new(location: @location, cell_type: :th)
      cell.add_child(ReVIEW::AST::TextNode.new(location: @location, content: cell_content))
      header_row.add_child(cell)
    end
    table.add_header_row(header_row)

    # Add body rows
    [['Alice', '25'], ['Bob', '30']].each do |row_data|
      body_row = ReVIEW::AST::TableRowNode.new(location: @location)
      row_data.each_with_index do |cell_content, index|
        # First cell in body rows is typically a header (row header)
        cell_type = index == 0 ? :th : :td
        cell = ReVIEW::AST::TableCellNode.new(location: @location, cell_type: cell_type)
        cell.add_child(ReVIEW::AST::TextNode.new(location: @location, content: cell_content))
        body_row.add_child(cell)
      end
      table.add_body_row(body_row)
    end

    doc.add_child(table)

    result = @generator.generate(doc)
    expected = <<~EOB
      //table[sample][Sample Table]{
      Name	Age
      ------------
      Alice	25
      Bob	30
      //}

    EOB
    assert_equal expected, result
  end

  def test_image
    doc = ReVIEW::AST::DocumentNode.new
    image = ReVIEW::AST::ImageNode.new(
      id: 'figure1',
      caption: 'Sample Figure'
    )
    doc.add_child(image)

    result = @generator.generate(doc)
    assert_equal "//image[figure1][Sample Figure]\n\n", result
  end

  def test_minicolumn
    doc = ReVIEW::AST::DocumentNode.new
    minicolumn = ReVIEW::AST::MinicolumnNode.new(
      minicolumn_type: :note,
      caption: 'Important Note'
    )
    para = ReVIEW::AST::ParagraphNode.new
    para.add_child(ReVIEW::AST::TextNode.new(content: 'This is a note.'))
    minicolumn.add_child(para)
    doc.add_child(minicolumn)

    result = @generator.generate(doc)
    expected = <<~EOB
      //note[Important Note]{
      This is a note.

      //}

    EOB
    assert_equal expected, result
  end

  def test_complex_document
    doc = ReVIEW::AST::DocumentNode.new

    # Headline
    h1 = ReVIEW::AST::HeadlineNode.new(level: 1, caption: 'Chapter 1')
    doc.add_child(h1)

    # Paragraph with inline
    para = ReVIEW::AST::ParagraphNode.new
    para.add_child(ReVIEW::AST::TextNode.new(content: 'This is '))
    code_inline = ReVIEW::AST::InlineNode.new(inline_type: 'code')
    code_inline.add_child(ReVIEW::AST::TextNode.new(content: 'inline code'))
    para.add_child(code_inline)
    para.add_child(ReVIEW::AST::TextNode.new(content: '.'))
    h1.add_child(para)

    # Code block
    code = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'example',
      original_text: 'puts "Hello, Re:VIEW!"'
    )

    # Add code line node
    line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
    line_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'puts "Hello, Re:VIEW!"'))
    code.add_child(line_node)

    h1.add_child(code)

    result = @generator.generate(doc)
    expected = <<~EOB
      = Chapter 1

      This is @<code>{inline code}.

      //list[example]{
      puts "Hello, Re:VIEW!"
      //}

    EOB
    assert_equal expected, result
  end

  def test_inline_with_args
    doc = ReVIEW::AST::DocumentNode.new
    para = ReVIEW::AST::ParagraphNode.new

    # href with URL
    href = ReVIEW::AST::InlineNode.new(inline_type: 'href')
    href.args = ['https://example.com']
    para.add_child(href)

    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "@<href>{https://example.com}\n\n", result
  end

  def test_ordered_list
    doc = ReVIEW::AST::DocumentNode.new
    list = ReVIEW::AST::ListNode.new(list_type: :ol)

    item1 = ReVIEW::AST::ListItemNode.new(level: 1, number: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(content: 'First'))
    list.add_child(item1)

    item2 = ReVIEW::AST::ListItemNode.new(level: 1, number: 2)
    item2.add_child(ReVIEW::AST::TextNode.new(content: 'Second'))
    list.add_child(item2)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = <<~EOB
      1. First
      2. Second

    EOB
    assert_equal expected, result
  end

  def test_definition_list
    doc = ReVIEW::AST::DocumentNode.new
    list = ReVIEW::AST::ListNode.new(list_type: :dl)

    item = ReVIEW::AST::ListItemNode.new(level: 1)
    item.add_child(ReVIEW::AST::TextNode.new(content: 'Term'))
    item.add_child(ReVIEW::AST::TextNode.new(content: 'Definition of the term'))
    list.add_child(item)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = <<~EOB
      : Term
      	Definition of the term

    EOB
    assert_equal expected, result
  end

  def test_empty_paragraph_skipped
    doc = ReVIEW::AST::DocumentNode.new

    # Non-empty paragraph
    para1 = ReVIEW::AST::ParagraphNode.new
    para1.add_child(ReVIEW::AST::TextNode.new(content: 'Content'))
    doc.add_child(para1)

    # Empty paragraph (should be skipped)
    para2 = ReVIEW::AST::ParagraphNode.new
    doc.add_child(para2)

    # Another non-empty paragraph
    para3 = ReVIEW::AST::ParagraphNode.new
    para3.add_child(ReVIEW::AST::TextNode.new(content: 'More content'))
    doc.add_child(para3)

    result = @generator.generate(doc)
    expected = <<~EOB
      Content

      More content

    EOB
    assert_equal expected, result
  end
end
