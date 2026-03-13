# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/review_generator'
require 'review/ast/code_line_node'
require 'review/ast/table_row_node'
require 'review/ast/table_cell_node'
require 'review/ast/reference_node'
require 'review/ast/footnote_node'

class TestASTReVIEWGenerator < Test::Unit::TestCase
  def setup
    @generator = ReVIEW::AST::ReVIEWGenerator.new
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_empty_document
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    result = @generator.generate(doc)
    assert_equal '', result
  end

  def test_headline
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Create caption node
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Introduction'))

    headline = ReVIEW::AST::HeadlineNode.new(
      location: @location,
      level: 2,
      label: 'intro',
      caption_node: caption_node
    )
    doc.add_child(headline)

    result = @generator.generate(doc)
    assert_equal "=={intro} Introduction\n\n", result
  end

  def test_paragraph_with_text
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Hello, world!'))
    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "Hello, world!\n\n", result
  end

  def test_inline_elements
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'This is '))

    bold = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :b)
    bold.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'bold'))
    para.add_child(bold)

    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: ' text.'))
    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "This is @<b>{bold} text.\n\n", result
  end

  def test_code_block_with_id
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Create caption node
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello Example'))

    code = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'hello',
      caption_node: caption_node,
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
      //list[hello][Hello Example][ruby]{
      def hello
        puts "Hello"
      end
      //}

    EOB
    assert_equal expected, result
  end

  def test_code_block_without_id
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
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
      //emlist[][sh]{
      echo "Hello"
      //}

    EOB
    assert_equal expected, result
  end

  def test_unordered_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)

    item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'First item'))
    list.add_child(item1)

    item2 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1)
    item2.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Second item'))
    list.add_child(item2)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = " * First item\n * Second item\n\n"
    assert_equal expected, result
  end

  def test_table
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Create caption node
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Sample Table'))

    table = ReVIEW::AST::TableNode.new(
      location: @location,
      id: 'sample',
      caption_node: caption_node
    )

    # Add header row
    header_row = ReVIEW::AST::TableRowNode.new(location: @location, row_type: :header)
    ['Name', 'Age'].each do |cell_content|
      cell = ReVIEW::AST::TableCellNode.new(location: @location, cell_type: :th)
      cell.add_child(ReVIEW::AST::TextNode.new(location: @location, content: cell_content))
      header_row.add_child(cell)
    end
    table.add_header_row(header_row)

    # Add body rows
    [['Alice', '25'], ['Bob', '30']].each do |row_data|
      body_row = ReVIEW::AST::TableRowNode.new(location: @location, row_type: :body)
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
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Create caption node
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Sample Figure'))

    image = ReVIEW::AST::ImageNode.new(
      location: @location,
      id: 'figure1',
      caption_node: caption_node
    )
    doc.add_child(image)

    result = @generator.generate(doc)
    assert_equal "//image[figure1][Sample Figure]\n\n", result
  end

  def test_minicolumn
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Create caption node
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Important Note'))

    minicolumn = ReVIEW::AST::MinicolumnNode.new(
      location: @location,
      minicolumn_type: :note,
      caption_node: caption_node
    )
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'This is a note.'))
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
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Headline with caption
    h1_caption = ReVIEW::AST::CaptionNode.new(location: @location)
    h1_caption.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Chapter 1'))

    h1 = ReVIEW::AST::HeadlineNode.new(location: @location, level: 1, caption_node: h1_caption)
    doc.add_child(h1)

    # Paragraph with inline
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'This is '))
    code_inline = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :code)
    code_inline.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'inline code'))
    para.add_child(code_inline)
    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: '.'))
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
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # href with URL
    href = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :href, args: ['https://example.com'])
    para.add_child(href)

    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "@<href>{https://example.com}\n\n", result
  end

  def test_ordered_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ol)

    item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1, number: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'First'))
    list.add_child(item1)

    item2 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1, number: 2)
    item2.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Second'))
    list.add_child(item2)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = " 1. First\n 2. Second\n\n"
    assert_equal expected, result
  end

  def test_definition_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :dl)

    item = ReVIEW::AST::ListItemNode.new(
      location: ReVIEW::SnapshotLocation.new(nil, 0),
      level: 1,
      term_children: [ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Term')]
    )
    item.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Definition of the term'))
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
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # Non-empty paragraph
    para1 = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Content'))
    doc.add_child(para1)

    # Empty paragraph (should be skipped)
    para2 = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(para2)

    # Another non-empty paragraph
    para3 = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para3.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'More content'))
    doc.add_child(para3)

    result = @generator.generate(doc)
    expected = <<~EOB
      Content

      More content

    EOB
    assert_equal expected, result
  end

  def test_nested_unordered_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)

    # First item with nested list
    item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Item 1'))

    # Nested list
    nested_list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)
    nested_item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 2)
    nested_item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Nested 1'))
    nested_list.add_child(nested_item1)

    nested_item2 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 2)
    nested_item2.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Nested 2'))
    nested_list.add_child(nested_item2)

    item1.add_child(nested_list)
    list.add_child(item1)

    # Second top-level item
    item2 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1)
    item2.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Item 2'))
    list.add_child(item2)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = " * Item 1\n ** Nested 1\n ** Nested 2\n * Item 2\n\n"
    assert_equal expected, result
  end

  def test_nested_ordered_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ol)

    # First item with nested list
    item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1, number: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'First'))

    # Nested ordered list
    nested_list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ol)
    nested_item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 2, number: 1)
    nested_item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Nested First'))
    nested_list.add_child(nested_item1)

    item1.add_child(nested_list)
    list.add_child(item1)

    # Second top-level item
    item2 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1, number: 2)
    item2.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Second'))
    list.add_child(item2)

    doc.add_child(list)

    result = @generator.generate(doc)
    expected = " 1. First\n 1. Nested First\n 2. Second\n\n"
    assert_equal expected, result
  end

  def test_reference_node
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # ReferenceNode is typically a child of InlineNode, but can also be standalone
    reference = ReVIEW::AST::ReferenceNode.new('fig1', nil, location: @location)
    para.add_child(reference)

    doc.add_child(para)

    result = @generator.generate(doc)
    # ReferenceNode should output its content (the ref_id)
    assert_equal "fig1\n\n", result
  end

  def test_footnote_node
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # FootnoteNode with content
    footnote = ReVIEW::AST::FootnoteNode.new(location: @location, id: 'note1')
    footnote.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'This is a footnote'))

    doc.add_child(footnote)

    result = @generator.generate(doc)
    # FootnoteNode should be rendered as //footnote[id][content]
    assert_equal "//footnote[note1][This is a footnote]\n\n", result
  end

  # Edge case tests
  def test_empty_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)
    doc.add_child(list)

    result = @generator.generate(doc)
    # Empty list should produce empty string
    assert_equal '', result
  end

  def test_multiple_inline_elements
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Text with '))

    bold = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :b)
    bold.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'bold'))
    para.add_child(bold)

    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: ' and '))

    italic = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :i)
    italic.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'italic'))
    para.add_child(italic)

    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: ' and '))

    code = ReVIEW::AST::InlineNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), inline_type: :code)
    code.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'code'))
    para.add_child(code)

    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: '.'))

    doc.add_child(para)

    result = @generator.generate(doc)
    assert_equal "Text with @<b>{bold} and @<i>{italic} and @<code>{code}.\n\n", result
  end

  def test_deeply_nested_list
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    list = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)

    # Level 1
    item1 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 1)
    item1.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Level 1'))

    # Level 2
    list2 = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)
    item2 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 2)
    item2.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Level 2'))

    # Level 3
    list3 = ReVIEW::AST::ListNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), list_type: :ul)
    item3 = ReVIEW::AST::ListItemNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), level: 3)
    item3.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Level 3'))
    list3.add_child(item3)

    item2.add_child(list3)
    list2.add_child(item2)
    item1.add_child(list2)
    list.add_child(item1)
    doc.add_child(list)

    result = @generator.generate(doc)
    assert_equal " * Level 1\n ** Level 2\n *** Level 3\n\n", result
  end

  def test_code_block_without_original_text
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    # CodeBlockNode without original_text (reconstructed from AST)
    code = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'sample',
      lang: 'ruby'
    )

    # Add code line nodes
    ['line 1', 'line 2', 'line 3'].each do |line|
      line_node = ReVIEW::AST::CodeLineNode.new(location: @location)
      line_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: line))
      code.add_child(line_node)
    end

    doc.add_child(code)

    result = @generator.generate(doc)
    expected = <<~EOB
      //list[sample][][ruby]{
      line 1
      line 2
      line 3
      //}

    EOB
    assert_equal expected, result
  end

  def test_image_with_metric
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Scaled Image'))

    image = ReVIEW::AST::ImageNode.new(
      location: @location,
      id: 'figure1',
      caption_node: caption_node,
      metric: 'scale=0.5'
    )
    doc.add_child(image)

    result = @generator.generate(doc)
    assert_equal "//image[figure1][Scaled Image][scale=0.5]\n\n", result
  end

  def test_column
    doc = ReVIEW::AST::DocumentNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))

    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Column Title'))

    column = ReVIEW::AST::ColumnNode.new(
      location: @location,
      level: 2,
      caption_node: caption_node
    )

    para = ReVIEW::AST::ParagraphNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0))
    para.add_child(ReVIEW::AST::TextNode.new(location: ReVIEW::SnapshotLocation.new(nil, 0), content: 'Column content.'))
    column.add_child(para)

    doc.add_child(column)

    result = @generator.generate(doc)
    assert_equal "==[column] Column Title\n\nColumn content.\n\n==[/column]\n\n", result
  end
end
