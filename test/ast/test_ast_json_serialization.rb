# frozen_string_literal: true

require_relative '../test_helper'
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
    # Test with a concrete node class instead of abstract Node
    node = AST::ParagraphNode.new(location: @location)
    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'ParagraphNode', parsed['type']
    assert_equal 'test.re', parsed['location']['filename']
    assert_equal 42, parsed['location']['lineno']
    assert_equal [], parsed['children']
  end

  def test_headline_node_serialization
    node = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      label: 'intro',
      caption_node: CaptionParserHelper.parse('Introduction', location: @location)
    )

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 1, parsed['level']
    assert_equal 'intro', parsed['label']
    expected_caption_node = {
      'children' => [{ 'content' => 'Introduction',
                       'location' => { 'filename' => 'test.re', 'lineno' => 42 },
                       'type' => 'TextNode' }],
      'location' => { 'filename' => 'test.re', 'lineno' => 42 },
      'type' => 'CaptionNode'
    }
    assert_equal expected_caption_node, parsed['caption_node']
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
      inline_type: :b,
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
      caption_node: CaptionParserHelper.parse('Example Code', location: @location),
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
    assert_equal expected_caption, parsed['caption_node']
    assert_equal 'ruby', parsed['lang']
    assert_equal lines_text, parsed['original_text']
    assert_equal true, parsed['line_numbers']
    assert_equal 3, parsed['children'].size # Check we have 3 code line nodes
  end

  def test_table_node_serialization
    node = AST::TableNode.new(
      location: @location,
      id: 'data',
      caption_node: CaptionParserHelper.parse('Sample Data', location: @location)
    )

    # Add header row
    header_row = AST::TableRowNode.new(location: @location, row_type: :header)
    ['Name', 'Age'].each do |cell_content|
      cell = AST::TableCellNode.new(location: @location)
      cell.add_child(AST::TextNode.new(location: @location, content: cell_content))
      header_row.add_child(cell)
    end
    node.add_header_row(header_row)

    # Add body rows
    [['Alice', '25'], ['Bob', '30']].each do |row_data|
      body_row = AST::TableRowNode.new(location: @location, row_type: :body)
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
    assert_equal expected_caption, parsed['caption_node']
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
      level: 1
    )
    text1 = AST::TextNode.new(location: @location, content: 'First item')
    item1.add_child(text1)
    list.add_child(item1)

    item2 = AST::ListItemNode.new(
      location: @location,
      level: 1
    )
    text2 = AST::TextNode.new(location: @location, content: 'Second item')
    item2.add_child(text2)
    list.add_child(item2)

    json = list.to_json
    parsed = JSON.parse(json)

    assert_equal 'ListNode', parsed['type']
    assert_equal 'ul', parsed['list_type']
    assert_equal 2, parsed['children'].size
    # Check that text content is in the children of each list item
    assert_equal 1, parsed['children'][0]['children'].size
    assert_equal 'First item', parsed['children'][0]['children'][0]['content']
    assert_equal 1, parsed['children'][1]['children'].size
    assert_equal 'Second item', parsed['children'][1]['children'][0]['content']
  end

  def test_embed_node_serialization
    node = AST::EmbedNode.new(
      location: @location,
      embed_type: :block,
      target_builders: ['html'],
      content: "<div>HTML content</div>\n<p>Paragraph</p>"
    )

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'EmbedNode', parsed['type']
    assert_equal 'block', parsed['embed_type']
    assert_equal ['html'], parsed['target_builders']
    assert_equal "<div>HTML content</div>\n<p>Paragraph</p>", parsed['content']
  end

  def test_document_node_serialization
    doc = AST::DocumentNode.new(
      location: @location
    )

    headline = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      caption_node: CaptionParserHelper.parse('Chapter 1', location: @location)
    )
    doc.add_child(headline)

    para = AST::ParagraphNode.new(
      location: @location
    )
    para_text = AST::TextNode.new(location: @location, content: 'Test paragraph')
    para.add_child(para_text)
    doc.add_child(para)

    json = doc.to_json
    parsed = JSON.parse(json)

    assert_equal 'DocumentNode', parsed['type']
    assert_equal 2, parsed['children'].size
    assert_equal 'HeadlineNode', parsed['children'][0]['type']
    assert_equal 'ParagraphNode', parsed['children'][1]['type']
  end

  def test_custom_json_serializer_basic
    node = AST::HeadlineNode.new(
      location: @location,
      level: 2,
      caption_node: CaptionParserHelper.parse('Section Title', location: @location)
    )

    options = AST::JSONSerializer::Options.new
    json = AST::JSONSerializer.serialize(node, options)
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 2, parsed['level']
    expected_caption = {
      'children' => [{ 'content' => 'Section Title',
                       'location' => { 'filename' => 'test.re', 'lineno' => 42 },
                       'type' => 'TextNode' }],
      'location' => { 'filename' => 'test.re', 'lineno' => 42 },
      'type' => 'CaptionNode'
    }
    assert_equal expected_caption, parsed['caption_node']
  end

  def test_custom_json_serializer_without_location
    node = AST::HeadlineNode.new(
      location: @location,
      level: 2,
      caption_node: CaptionParserHelper.parse('Section Title', location: @location)
    )

    options = AST::JSONSerializer::Options.new
    options.include_location = false

    json = AST::JSONSerializer.serialize(node, options)
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 2, parsed['level']
    expected_caption = {
      'children' => [{ 'content' => 'Section Title', 'type' => 'TextNode' }],
      'type' => 'CaptionNode'
    }
    assert_equal expected_caption, parsed['caption_node']
    assert_nil(parsed['location'])
  end

  def test_custom_json_serializer_compact
    node = AST::HeadlineNode.new(
      location: @location,
      level: 2,
      caption_node: CaptionParserHelper.parse('Section Title', location: @location)
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
      location: @location
    )

    # Add headline
    headline = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      caption_node: CaptionParserHelper.parse('Introduction', location: @location)
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
      inline_type: :code,
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
      caption_node: CaptionParserHelper.parse('Code Example', location: @location),
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
                   'type' => 'CaptionNode' }, headline_json['caption_node'])

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
    assert_equal expected_caption, code_json['caption_node']
    assert_equal 'ruby', code_json['lang']
    assert_equal 'puts "Hello, World!"', code_json['original_text']
    assert_equal 1, code_json['children'].size # Check we have 1 code line node
  end

  def test_include_location_option_with_true
    # Test that location information is included when include_location is true (default)
    paragraph = AST::ParagraphNode.new(location: @location)
    text_node = AST::TextNode.new(location: @location, content: 'Test content')
    paragraph.add_child(text_node)

    options = AST::JSONSerializer::Options.new(include_location: true)
    json = AST::JSONSerializer.serialize(paragraph, options)
    parsed = JSON.parse(json)

    # Check that location is included in parent node
    assert_not_nil(parsed['location'], 'location should be included when include_location is true')
    assert_equal 'test.re', parsed['location']['filename']
    assert_equal 42, parsed['location']['lineno']

    # Check that location is included in child nodes
    assert_equal 1, parsed['children'].size
    child = parsed['children'][0]
    assert_not_nil(child['location'], 'location should be included in child nodes when include_location is true')
    assert_equal 'test.re', child['location']['filename']
    assert_equal 42, child['location']['lineno']
  end

  def test_include_location_option_with_false
    # Test that location information is excluded when include_location is false
    paragraph = AST::ParagraphNode.new(location: @location)
    text_node = AST::TextNode.new(location: @location, content: 'Test content')
    paragraph.add_child(text_node)

    options = AST::JSONSerializer::Options.new(include_location: false)
    json = AST::JSONSerializer.serialize(paragraph, options)
    parsed = JSON.parse(json)

    # Check that location is not included in parent node
    assert_nil(parsed['location'], 'location should not be included when include_location is false')

    # Check that location is not included in child nodes
    assert_equal 1, parsed['children'].size
    child = parsed['children'][0]
    assert_nil(child['location'], 'location should not be included in child nodes when include_location is false')
  end

  def test_include_location_with_complex_tree
    # Test include_location with a more complex node tree
    headline = AST::HeadlineNode.new(
      location: @location,
      level: 1,
      caption_node: CaptionParserHelper.parse('Test Headline', location: @location)
    )

    # Test with include_location = true
    options_with_location = AST::JSONSerializer::Options.new(include_location: true)
    json_with_location = AST::JSONSerializer.serialize(headline, options_with_location)
    parsed_with_location = JSON.parse(json_with_location)

    assert_not_nil(parsed_with_location['location'])
    assert_not_nil(parsed_with_location['caption_node']['location'])
    caption_children = parsed_with_location['caption_node']['children']
    assert_equal 1, caption_children.size
    assert_not_nil(caption_children[0]['location'])

    # Test with include_location = false
    options_without_location = AST::JSONSerializer::Options.new(include_location: false)
    json_without_location = AST::JSONSerializer.serialize(headline, options_without_location)
    parsed_without_location = JSON.parse(json_without_location)

    assert_nil(parsed_without_location['location'])
    assert_nil(parsed_without_location['caption_node']['location'])
    caption_children = parsed_without_location['caption_node']['children']
    assert_equal 1, caption_children.size
    assert_nil(caption_children[0]['location'])
  end

  def test_footnote_node_serialization
    # Create a footnote node with children
    footnote = AST::FootnoteNode.new(
      location: @location,
      id: 'fn1',
      footnote_type: :footnote
    )

    text = AST::TextNode.new(
      location: @location,
      content: 'This is a footnote text.'
    )
    footnote.add_child(text)

    # Serialize to JSON
    json = footnote.to_json
    parsed = JSON.parse(json)

    # Verify serialization
    assert_equal 'FootnoteNode', parsed['type']
    assert_equal 'fn1', parsed['id']
    # footnote_type is omitted when it's :footnote (default)
    assert_nil(parsed['footnote_type'])
    assert_equal 1, parsed['children'].size
    assert_equal 'TextNode', parsed['children'][0]['type']
    assert_equal 'This is a footnote text.', parsed['children'][0]['content']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::FootnoteNode, deserialized)
    assert_equal 'fn1', deserialized.id
    assert_equal :footnote, deserialized.footnote_type
    assert_equal 1, deserialized.children.size
    assert_equal 'This is a footnote text.', deserialized.children[0].content
  end

  def test_footnote_node_endnote_serialization
    # Create an endnote node
    endnote = AST::FootnoteNode.new(
      location: @location,
      id: 'en1',
      footnote_type: :endnote
    )

    text = AST::TextNode.new(
      location: @location,
      content: 'This is an endnote.'
    )
    endnote.add_child(text)

    # Serialize to JSON
    json = endnote.to_json
    parsed = JSON.parse(json)

    # Verify serialization - endnote type should be included
    assert_equal 'FootnoteNode', parsed['type']
    assert_equal 'en1', parsed['id']
    assert_equal 'endnote', parsed['footnote_type']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::FootnoteNode, deserialized)
    assert_equal 'en1', deserialized.id
    assert_equal :endnote, deserialized.footnote_type
  end

  def test_reference_node_unresolved_serialization
    # Create an unresolved reference node
    ref = AST::ReferenceNode.new(
      'img1',
      nil,
      location: @location
    )

    # Serialize to JSON
    json = ref.to_json
    parsed = JSON.parse(json)

    # Verify serialization
    assert_equal 'ReferenceNode', parsed['type']
    assert_equal 'img1', parsed['content']
    assert_equal 'img1', parsed['ref_id']
    assert_nil(parsed['context_id'])
    assert_nil(parsed['resolved_data'])

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ReferenceNode, deserialized)
    assert_equal 'img1', deserialized.ref_id
    assert_nil(deserialized.context_id)
    assert_nil(deserialized.resolved_data)
    assert_equal false, deserialized.resolved?
  end

  def test_reference_node_with_context_serialization
    # Create a cross-chapter reference node
    ref = AST::ReferenceNode.new(
      'img1',
      'chapter2',
      location: @location
    )

    # Serialize to JSON
    json = ref.to_json
    parsed = JSON.parse(json)

    # Verify serialization
    assert_equal 'ReferenceNode', parsed['type']
    assert_equal 'chapter2|img1', parsed['content']
    assert_equal 'img1', parsed['ref_id']
    assert_equal 'chapter2', parsed['context_id']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ReferenceNode, deserialized)
    assert_equal 'img1', deserialized.ref_id
    assert_equal 'chapter2', deserialized.context_id
    assert_equal true, deserialized.cross_chapter?
  end

  def test_reference_node_with_image_reference_serialization
    # Create resolved image reference
    caption_node = CaptionParserHelper.parse('Sample Image', location: @location)
    resolved_data = AST::ResolvedData.image(
      chapter_number: 1, chapter_type: :chapter,
      item_number: '2',
      item_id: 'img1',
      caption_node: caption_node
    )

    ref = AST::ReferenceNode.new(
      'img1',
      nil,
      location: @location,
      resolved_data: resolved_data
    )

    # Serialize to JSON
    json = ref.to_json
    parsed = JSON.parse(json)

    # Verify serialization
    assert_equal 'ReferenceNode', parsed['type']
    assert_equal 'img1', parsed['ref_id']
    assert_not_nil(parsed['resolved_data'])
    assert_equal 'ImageReference', parsed['resolved_data']['type']
    assert_equal 1, parsed['resolved_data']['chapter_number']
    assert_equal '2', parsed['resolved_data']['item_number']
    assert_equal 'img1', parsed['resolved_data']['item_id']
    assert_equal 'CaptionNode', parsed['resolved_data']['caption_node']['type']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ReferenceNode, deserialized)
    assert_equal true, deserialized.resolved?
    assert_instance_of(AST::ResolvedData::ImageReference, deserialized.resolved_data)
    assert_equal 1, deserialized.resolved_data.chapter_number
    assert_equal '2', deserialized.resolved_data.item_number
    assert_equal 'img1', deserialized.resolved_data.item_id
    assert_instance_of(AST::CaptionNode, deserialized.resolved_data.caption_node)
  end

  def test_reference_node_with_table_reference_serialization
    # Create resolved table reference
    resolved_data = AST::ResolvedData.table(
      chapter_number: 2, chapter_type: :chapter,
      item_number: '1',
      item_id: 'table1',
      chapter_id: 'ch2'
    )

    ref = AST::ReferenceNode.new(
      'table1',
      'ch2',
      location: @location,
      resolved_data: resolved_data
    )

    json = ref.to_json
    parsed = JSON.parse(json)

    assert_equal 'TableReference', parsed['resolved_data']['type']
    assert_equal 2, parsed['resolved_data']['chapter_number']
    assert_equal '1', parsed['resolved_data']['item_number']
    assert_equal 'ch2', parsed['resolved_data']['chapter_id']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ResolvedData::TableReference, deserialized.resolved_data)
    assert_equal 2, deserialized.resolved_data.chapter_number
  end

  def test_reference_node_with_chapter_reference_serialization
    # Create resolved chapter reference
    resolved_data = AST::ResolvedData.chapter(
      chapter_number: 3, chapter_type: :chapter,
      chapter_id: 'ch3',
      item_id: 'ch3',
      chapter_title: 'Advanced Topics'
    )

    ref = AST::ReferenceNode.new(
      'ch3',
      nil,
      location: @location,
      resolved_data: resolved_data
    )

    json = ref.to_json
    parsed = JSON.parse(json)

    assert_equal 'ChapterReference', parsed['resolved_data']['type']
    assert_equal 3, parsed['resolved_data']['chapter_number']
    assert_equal 'ch3', parsed['resolved_data']['chapter_id']
    assert_equal 'Advanced Topics', parsed['resolved_data']['chapter_title']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ResolvedData::ChapterReference, deserialized.resolved_data)
    assert_equal 3, deserialized.resolved_data.chapter_number
    assert_equal 'Advanced Topics', deserialized.resolved_data.chapter_title
  end

  def test_reference_node_with_headline_reference_serialization
    # Create resolved headline reference
    caption_node = CaptionParserHelper.parse('Section Title', location: @location)
    resolved_data = AST::ResolvedData.headline(
      headline_number: [1, 2, 3],
      item_id: 'sec123',
      chapter_id: 'ch1',
      chapter_number: 1, chapter_type: :chapter,
      caption_node: caption_node
    )

    ref = AST::ReferenceNode.new(
      'sec123',
      nil,
      location: @location,
      resolved_data: resolved_data
    )

    json = ref.to_json
    parsed = JSON.parse(json)

    assert_equal 'HeadlineReference', parsed['resolved_data']['type']
    assert_equal [1, 2, 3], parsed['resolved_data']['headline_number']
    assert_equal 'sec123', parsed['resolved_data']['item_id']
    assert_equal 'ch1', parsed['resolved_data']['chapter_id']
    assert_equal 1, parsed['resolved_data']['chapter_number']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ResolvedData::HeadlineReference, deserialized.resolved_data)
    assert_equal [1, 2, 3], deserialized.resolved_data.headline_number
  end

  def test_reference_node_with_footnote_reference_serialization
    # Create resolved footnote reference
    resolved_data = AST::ResolvedData.footnote(
      item_number: 5,
      item_id: 'fn5'
    )

    ref = AST::ReferenceNode.new(
      'fn5',
      nil,
      location: @location,
      resolved_data: resolved_data
    )

    json = ref.to_json
    parsed = JSON.parse(json)

    assert_equal 'FootnoteReference', parsed['resolved_data']['type']
    assert_equal 5, parsed['resolved_data']['item_number']
    assert_equal 'fn5', parsed['resolved_data']['item_id']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ResolvedData::FootnoteReference, deserialized.resolved_data)
    assert_equal 5, deserialized.resolved_data.item_number
  end

  def test_reference_node_with_word_reference_serialization
    # Create resolved word reference
    resolved_data = AST::ResolvedData.word(
      word_content: 'important term',
      item_id: 'term1'
    )

    ref = AST::ReferenceNode.new(
      'term1',
      nil,
      location: @location,
      resolved_data: resolved_data
    )

    json = ref.to_json
    parsed = JSON.parse(json)

    assert_equal 'WordReference', parsed['resolved_data']['type']
    assert_equal 'important term', parsed['resolved_data']['word_content']
    assert_equal 'term1', parsed['resolved_data']['item_id']

    # Test deserialization
    deserialized = AST::JSONSerializer.deserialize(json)
    assert_instance_of(AST::ResolvedData::WordReference, deserialized.resolved_data)
    assert_equal 'important term', deserialized.resolved_data.word_content
  end
end
