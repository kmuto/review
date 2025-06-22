# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/json_serializer'
require 'review/ast/code_line_node'
require 'review/ast/table_row_node'
require 'review/ast/table_cell_node'
require 'json'

class TestASTJSONSerialization < Test::Unit::TestCase
  include ReVIEW

  def setup
    @location = SnapshotLocation.new('test.re', 42)
  end

  def test_basic_node_serialization
    node = AST::Node.new(location: @location)
    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'Node', parsed['type']
    assert_equal 'test.re', parsed['location']['filename']
    assert_equal 42, parsed['location']['lineno']
    assert_equal [], parsed['children']
  end

  def test_headline_node_serialization
    node = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      label: 'intro',
      caption: AST::CaptionNode.parse('Introduction', location: @location)
    )

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 1, parsed['level']
    assert_equal 'intro', parsed['label']
    assert_equal({ 'children' =>
  [{ 'content' => 'Introduction',
     'location' => { 'filename' => 'test.re', 'lineno' => 42 },
     'type' => 'TextNode' }],
                   'location' => { 'filename' => 'test.re', 'lineno' => 42 },
                   'type' => 'CaptionNode' }, parsed['caption'])
  end

  def test_paragraph_with_inline_elements
    para = AST::ParagraphNode.new(location: @location)

    # Add text node
    text1 = AST::TextNode.new(
      location: @location,
      content: 'This is '
    )
    para.add_child(text1)

    # Add inline node
    inline = AST::InlineNode.new(
      location: @location,
      inline_type: 'b',
      args: ['bold']
    )

    inline_text = AST::TextNode.new(
      location: @location,
      content: 'bold'
    )
    inline.add_child(inline_text)

    para.add_child(inline)

    # Add more text
    text2 = AST::TextNode.new(
      location: @location,
      content: ' text.'
    )
    para.add_child(text2)

    json = para.to_json
    parsed = JSON.parse(json)

    assert_equal 'ParagraphNode', parsed['type']
    assert_equal 3, parsed['children'].size

    # Check first text node
    assert_equal 'TextNode', parsed['children'][0]['type']
    assert_equal 'This is ', parsed['children'][0]['content']

    # Check inline node
    inline_node = parsed['children'][1]
    assert_equal 'InlineNode', inline_node['type']
    assert_equal 'b', inline_node['inline_type']
    assert_equal ['bold'], inline_node['args']
    assert_equal 1, inline_node['children'].size
    assert_equal 'bold', inline_node['children'][0]['content']

    # Check last text node
    assert_equal 'TextNode', parsed['children'][2]['type']
    assert_equal ' text.', parsed['children'][2]['content']
  end

  def test_code_block_node_serialization
    lines_text = "def hello\n  puts \"world\"\nend"
    node = AST::CodeBlockNode.new(
      location: @location,
      id: 'example',
      caption: AST::CaptionNode.parse('Example Code', location: @location),
      lang: 'ruby',
      original_text: lines_text,
      line_numbers: true
    )

    # Add code line nodes to represent the structure
    ['def hello', '  puts "world"', 'end'].each_with_index do |line, index|
      line_node = AST::CodeLineNode.new(
        location: @location,
        line_number: index + 1
      )
      line_node.add_child(AST::TextNode.new(location: @location, content: line))
      node.add_child(line_node)
    end

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'CodeBlockNode', parsed['type']
    assert_equal 'example', parsed['id']
    expected_caption = {
      'type' => 'CaptionNode',
      'location' => { 'filename' => 'test.re', 'lineno' => 42 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Example Code',
          'location' => { 'filename' => 'test.re', 'lineno' => 42 }
        }
      ]
    }
    assert_equal expected_caption, parsed['caption']
    assert_equal 'ruby', parsed['lang']
    assert_equal lines_text, parsed['original_text']
    assert_equal true, parsed['line_numbers']
    assert_equal 3, parsed['children'].size # Check we have 3 code line nodes
  end

  def test_table_node_serialization
    node = AST::TableNode.new(
      location: @location,
      id: 'data',
      caption: AST::CaptionNode.parse('Sample Data', location: @location)
    )

    # Add header row
    header_row = AST::TableRowNode.new(location: @location)
    ['Name', 'Age'].each do |cell_content|
      cell = AST::TableCellNode.new(location: @location)
      cell.add_child(AST::TextNode.new(location: @location, content: cell_content))
      header_row.add_child(cell)
    end
    node.add_header_row(header_row)

    # Add body rows
    [['Alice', '25'], ['Bob', '30']].each do |row_data|
      body_row = AST::TableRowNode.new(location: @location)
      row_data.each do |cell_content|
        cell = AST::TableCellNode.new(location: @location)
        cell.add_child(AST::TextNode.new(location: @location, content: cell_content))
        body_row.add_child(cell)
      end
      node.add_body_row(body_row)
    end

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'TableNode', parsed['type']
    assert_equal 'data', parsed['id']
    expected_caption = {
      'type' => 'CaptionNode',
      'location' => { 'filename' => 'test.re', 'lineno' => 42 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Sample Data',
          'location' => { 'filename' => 'test.re', 'lineno' => 42 }
        }
      ]
    }
    assert_equal expected_caption, parsed['caption']
    assert_equal 1, parsed['header_rows'].size  # Check we have 1 header row
    assert_equal 2, parsed['body_rows'].size    # Check we have 2 body rows
  end

  def test_list_node_serialization
    list = AST::ListNode.new(
      location: @location,
      list_type: :ul
    )

    item1 = AST::ListItemNode.new(
      location: @location,
      content: 'First item',
      level: 1
    )
    list.add_child(item1)

    item2 = AST::ListItemNode.new(
      location: @location,
      content: 'Second item',
      level: 1
    )
    list.add_child(item2)

    json = list.to_json
    parsed = JSON.parse(json)

    assert_equal 'ListNode', parsed['type']
    assert_equal 'ul', parsed['list_type']
    assert_equal 2, parsed['children'].size
    assert_equal 'First item', parsed['children'][0]['content']
    assert_equal 'Second item', parsed['children'][1]['content']
  end

  def test_embed_node_serialization
    node = AST::EmbedNode.new(
      location: @location,
      embed_type: :block,
      arg: 'html',
      lines: ['<div>HTML content</div>', '<p>Paragraph</p>']
    )

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'EmbedNode', parsed['type']
    assert_equal 'block', parsed['embed_type']
    assert_equal 'html', parsed['arg']
    assert_equal ['<div>HTML content</div>', '<p>Paragraph</p>'], parsed['lines']
  end

  def test_document_node_serialization
    doc = AST::DocumentNode.new(
      location: @location,
      title: 'Test Document'
    )

    headline = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      caption: AST::CaptionNode.parse('Chapter 1', location: @location)
    )
    doc.add_child(headline)

    para = AST::ParagraphNode.new(
      location: @location,
      content: 'Test paragraph'
    )
    doc.add_child(para)

    json = doc.to_json
    parsed = JSON.parse(json)

    assert_equal 'DocumentNode', parsed['type']
    assert_equal 'Test Document', parsed['title']
    assert_equal 2, parsed['children'].size
    assert_equal 'HeadlineNode', parsed['children'][0]['type']
    assert_equal 'ParagraphNode', parsed['children'][1]['type']
  end

  def test_custom_json_serializer_basic
    node = AST::HeadlineNode.new(
      location: @location,
      level: 2,
      caption: AST::CaptionNode.parse('Section Title', location: @location)
    )

    options = AST::JSONSerializer::Options.new
    json = AST::JSONSerializer.serialize(node, options)
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 2, parsed['level']
    assert_equal({ 'children' =>
                  [{ 'content' => 'Section Title',
                     'location' => { 'filename' => 'test.re', 'lineno' => 42 },
                     'type' => 'TextNode' }],
                   'location' => { 'filename' => 'test.re', 'lineno' => 42 },
                   'type' => 'CaptionNode' }, parsed['caption'])
  end

  def test_custom_json_serializer_without_location
    node = AST::HeadlineNode.new(
      location: @location,
      level: 2,
      caption: AST::CaptionNode.parse('Section Title', location: @location)
    )

    options = AST::JSONSerializer::Options.new
    options.include_location = false

    json = AST::JSONSerializer.serialize(node, options)
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 2, parsed['level']
    assert_equal({ 'children' => [{ 'content' => 'Section Title', 'type' => 'TextNode' }],
                   'type' => 'CaptionNode' }, parsed['caption'])
    assert_nil(parsed['location'])
  end

  def test_custom_json_serializer_compact
    node = AST::HeadlineNode.new(
      location: @location,
      level: 2,
      caption: AST::CaptionNode.parse('Section Title', location: @location)
    )

    options = AST::JSONSerializer::Options.new
    options.pretty = false
    options.include_location = false

    json = AST::JSONSerializer.serialize(node, options)

    # Compact JSON should not have newlines
    assert_not_include(json, "\n")

    parsed = JSON.parse(json)
    assert_equal 'HeadlineNode', parsed['type']
  end

  def test_json_schema_structure
    schema = AST::JSONSerializer.json_schema

    assert_equal 'http://json-schema.org/draft-07/schema#', schema['$schema']
    assert_equal 'ReVIEW AST JSON Schema', schema['title']
    assert_equal 'object', schema['type']
    assert_include(schema['required'], 'type')

    # Check enum values for type
    type_enum = schema['properties']['type']['enum']
    assert_include(type_enum, 'DocumentNode')
    assert_include(type_enum, 'HeadlineNode')
    assert_include(type_enum, 'ParagraphNode')
    assert_include(type_enum, 'InlineNode')
  end

  def test_complex_nested_structure
    # Create a complex document structure
    doc = AST::DocumentNode.new(
      location: @location,
      title: 'Complex Document'
    )

    # Add headline
    headline = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      caption: AST::CaptionNode.parse('Introduction', location: @location)
    )
    doc.add_child(headline)

    # Add paragraph with inline elements
    para = AST::ParagraphNode.new(
      location: @location
    )

    text1 = AST::TextNode.new(
      location: @location,
      content: 'This paragraph has '
    )
    para.add_child(text1)

    inline = AST::InlineNode.new(
      location: @location,
      inline_type: 'code',
      args: ['inline code']
    )

    inline_text = AST::TextNode.new(
      location: @location,
      content: 'inline code'
    )
    inline.add_child(inline_text)
    para.add_child(inline)

    text2 = AST::TextNode.new(
      location: @location,
      content: ' elements.'
    )
    para.add_child(text2)

    doc.add_child(para)

    # Add code block
    code = AST::CodeBlockNode.new(
      location: @location,
      id: 'example',
      caption: AST::CaptionNode.parse('Code Example', location: @location),
      lang: 'ruby',
      original_text: 'puts "Hello, World!"'
    )

    # Add code line node
    line_node = AST::CodeLineNode.new(location: @location)
    line_node.add_child(AST::TextNode.new(location: @location, content: 'puts "Hello, World!"'))
    code.add_child(line_node)
    doc.add_child(code)

    # Serialize and verify
    json = doc.to_json
    parsed = JSON.parse(json)

    assert_equal 'DocumentNode', parsed['type']
    assert_equal 'Complex Document', parsed['title']
    assert_equal 3, parsed['children'].size

    # Check headline
    headline_json = parsed['children'][0]
    assert_equal 'HeadlineNode', headline_json['type']
    assert_equal 1, headline_json['level']
    assert_equal({ 'children' =>
  [{ 'content' => 'Introduction',
     'location' => { 'filename' => 'test.re', 'lineno' => 42 },
     'type' => 'TextNode' }],
                   'location' => { 'filename' => 'test.re', 'lineno' => 42 },
                   'type' => 'CaptionNode' }, headline_json['caption'])

    # Check paragraph with inline elements
    para_json = parsed['children'][1]
    assert_equal 'ParagraphNode', para_json['type']
    assert_equal 3, para_json['children'].size

    inline_json = para_json['children'][1]
    assert_equal 'InlineNode', inline_json['type']
    assert_equal 'code', inline_json['inline_type']
    assert_equal ['inline code'], inline_json['args']

    # Check code block
    code_json = parsed['children'][2]
    assert_equal 'CodeBlockNode', code_json['type']
    assert_equal 'example', code_json['id']
    expected_caption = {
      'type' => 'CaptionNode',
      'location' => { 'filename' => 'test.re', 'lineno' => 42 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Code Example',
          'location' => { 'filename' => 'test.re', 'lineno' => 42 }
        }
      ]
    }
    assert_equal expected_caption, code_json['caption']
    assert_equal 'ruby', code_json['lang']
    assert_equal 'puts "Hello, World!"', code_json['original_text']
    assert_equal 1, code_json['children'].size # Check we have 1 code line node
  end
end
