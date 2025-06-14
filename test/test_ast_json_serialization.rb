# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/json_serializer'
require 'json'

class TestASTJSONSerialization < Test::Unit::TestCase
  include ReVIEW

  def setup
    @location = Struct.new(:filename, :lineno).new('test.re', 42)
  end

  def test_basic_node_serialization
    node = AST::Node.new(@location)
    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'Node', parsed['type']
    assert_equal 'test.re', parsed['location']['filename']
    assert_equal 42, parsed['location']['lineno']
    assert_equal [], parsed['children']
  end

  def test_headline_node_serialization
    node = AST::HeadlineNode.new(@location)
    node.level = 1
    node.label = 'intro'
    node.caption = 'Introduction'

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 1, parsed['level']
    assert_equal 'intro', parsed['label']
    assert_equal 'Introduction', parsed['caption']
  end

  def test_paragraph_with_inline_elements
    para = AST::ParagraphNode.new(@location)

    # Add text node
    text1 = AST::TextNode.new(@location)
    text1.content = 'This is '
    para.add_child(text1)

    # Add inline node
    inline = AST::InlineNode.new(@location)
    inline.inline_type = 'b'
    inline.args = ['bold']

    inline_text = AST::TextNode.new(@location)
    inline_text.content = 'bold'
    inline.add_child(inline_text)

    para.add_child(inline)

    # Add more text
    text2 = AST::TextNode.new(@location)
    text2.content = ' text.'
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
    node = AST::CodeBlockNode.new(@location)
    node.id = 'example'
    node.caption = 'Example Code'
    node.lang = 'ruby'
    node.lines = ['def hello', '  puts "world"', 'end']
    node.line_numbers = true

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'CodeBlockNode', parsed['type']
    assert_equal 'example', parsed['id']
    assert_equal 'Example Code', parsed['caption']
    assert_equal 'ruby', parsed['lang']
    assert_equal ['def hello', '  puts "world"', 'end'], parsed['lines']
    assert_equal true, parsed['line_numbers']
  end

  def test_table_node_serialization
    node = AST::TableNode.new(@location)
    node.id = 'data'
    node.caption = 'Sample Data'
    node.headers = [['Name', 'Age']]
    node.rows = [['Alice', '25'], ['Bob', '30']]

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'TableNode', parsed['type']
    assert_equal 'data', parsed['id']
    assert_equal 'Sample Data', parsed['caption']
    assert_equal [['Name', 'Age']], parsed['headers']
    assert_equal [['Alice', '25'], ['Bob', '30']], parsed['rows']
  end

  def test_list_node_serialization
    list = AST::ListNode.new(@location)
    list.list_type = :ul

    item1 = AST::ListItemNode.new(@location)
    item1.content = 'First item'
    item1.level = 1
    list.items << item1

    item2 = AST::ListItemNode.new(@location)
    item2.content = 'Second item'
    item2.level = 1
    list.items << item2

    json = list.to_json
    parsed = JSON.parse(json)

    assert_equal 'ListNode', parsed['type']
    assert_equal 'ul', parsed['list_type']
    assert_equal 2, parsed['items'].size
    assert_equal 'First item', parsed['items'][0]['content']
    assert_equal 'Second item', parsed['items'][1]['content']
  end

  def test_embed_node_serialization
    node = AST::EmbedNode.new(@location)
    node.embed_type = :block
    node.arg = 'html'
    node.lines = ['<div>HTML content</div>', '<p>Paragraph</p>']

    json = node.to_json
    parsed = JSON.parse(json)

    assert_equal 'EmbedNode', parsed['type']
    assert_equal 'block', parsed['embed_type']
    assert_equal 'html', parsed['arg']
    assert_equal ['<div>HTML content</div>', '<p>Paragraph</p>'], parsed['lines']
  end

  def test_document_node_serialization
    doc = AST::DocumentNode.new(@location)
    doc.title = 'Test Document'

    headline = AST::HeadlineNode.new(@location)
    headline.level = 1
    headline.caption = 'Chapter 1'
    doc.add_child(headline)

    para = AST::ParagraphNode.new(@location)
    para.content = 'Test paragraph'
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
    node = AST::HeadlineNode.new(@location)
    node.level = 2
    node.caption = 'Section Title'

    options = AST::JSONSerializer::Options.new
    json = AST::JSONSerializer.serialize(node, options)
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 2, parsed['level']
    assert_equal 'Section Title', parsed['caption']
  end

  def test_custom_json_serializer_without_location
    node = AST::HeadlineNode.new(@location)
    node.level = 2
    node.caption = 'Section Title'

    options = AST::JSONSerializer::Options.new
    options.include_location = false

    json = AST::JSONSerializer.serialize(node, options)
    parsed = JSON.parse(json)

    assert_equal 'HeadlineNode', parsed['type']
    assert_equal 2, parsed['level']
    assert_equal 'Section Title', parsed['caption']
    assert_nil(parsed['location'])
  end

  def test_custom_json_serializer_compact
    node = AST::HeadlineNode.new(@location)
    node.level = 2
    node.caption = 'Section Title'

    options = AST::JSONSerializer::Options.new
    options.pretty = false
    options.include_location = false

    json = AST::JSONSerializer.serialize(node, options)

    # Compact JSON should not have newlines
    assert_not_include(json, "\n")

    parsed = JSON.parse(json)
    assert_equal 'HeadlineNode', parsed['type']
  end

  def test_pretty_json_method
    node = AST::HeadlineNode.new(@location)
    node.level = 1
    node.caption = 'Test'

    pretty_json = node.to_pretty_json

    assert_include(pretty_json, "\n")
    assert_include(pretty_json, '  ')

    parsed = JSON.parse(pretty_json)
    assert_equal 'HeadlineNode', parsed['type']
  end

  def test_compact_json_method
    node = AST::HeadlineNode.new(@location)
    node.level = 1
    node.caption = 'Test'

    compact_json = node.to_compact_json

    # Should not include location info
    parsed = JSON.parse(compact_json)
    assert_nil(parsed['location'])
    assert_equal 'HeadlineNode', parsed['type']
  end

  def test_json_with_options_method
    node = AST::HeadlineNode.new(@location)
    node.level = 1
    node.caption = 'Test'

    options = AST::JSONSerializer::Options.new
    options.include_location = false
    options.pretty = false

    json = node.to_json_with_options(options)
    parsed = JSON.parse(json)

    assert_nil(parsed['location'])
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
    doc = AST::DocumentNode.new(@location)
    doc.title = 'Complex Document'

    # Add headline
    headline = AST::HeadlineNode.new(@location)
    headline.level = 1
    headline.caption = 'Introduction'
    doc.add_child(headline)

    # Add paragraph with inline elements
    para = AST::ParagraphNode.new(@location)

    text1 = AST::TextNode.new(@location)
    text1.content = 'This paragraph has '
    para.add_child(text1)

    inline = AST::InlineNode.new(@location)
    inline.inline_type = 'code'
    inline.args = ['inline code']

    inline_text = AST::TextNode.new(@location)
    inline_text.content = 'inline code'
    inline.add_child(inline_text)
    para.add_child(inline)

    text2 = AST::TextNode.new(@location)
    text2.content = ' elements.'
    para.add_child(text2)

    doc.add_child(para)

    # Add code block
    code = AST::CodeBlockNode.new(@location)
    code.id = 'example'
    code.caption = 'Code Example'
    code.lang = 'ruby'
    code.lines = ['puts "Hello, World!"']
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
    assert_equal 'Introduction', headline_json['caption']

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
    assert_equal 'Code Example', code_json['caption']
    assert_equal 'ruby', code_json['lang']
    assert_equal ['puts "Hello, World!"'], code_json['lines']
  end
end
