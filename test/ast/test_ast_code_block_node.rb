# frozen_string_literal: true

require_relative '../test_helper'
require 'review/snapshot_location'
require 'review/ast/code_block_node'
require 'review/ast/paragraph_node'
require 'review/ast/text_node'
require 'review/ast/inline_node'
require 'review/ast/json_serializer'
require 'review/ast/compiler'
require 'review/ast/review_generator'
require 'review/configure'
require 'review/book'
require 'review/i18n'
require 'stringio'

class TestASTCodeBlockNode < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @location = create_test_location
    ReVIEW::I18n.setup(@config['language'])
  end

  def create_test_location
    ReVIEW::SnapshotLocation.new('test.re', 5)
  end

  def test_code_block_node_original_text_preservation
    lines = ['puts @<b>{hello}', 'puts "world"']
    original_text = lines.join("\n")

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'sample',
      original_text: original_text
    )

    assert_equal original_text, code_block.original_text
    assert_equal lines, code_block.original_lines
  end

  def test_code_block_node_processed_lines
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'sample',
      original_text: 'puts @<b>{hello}'
    )

    processed = code_block.processed_lines
    assert_equal 0, processed.size

    original = code_block.original_lines
    assert_equal 1, original.size
    assert_equal 'puts @<b>{hello}', original[0]
  end

  def test_original_lines_and_processed_lines
    original_text = 'puts @<b>{hello}'

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: original_text
    )

    assert_equal ['puts @<b>{hello}'], code_block.original_lines

    processed = code_block.processed_lines
    assert_equal 0, processed.size
  end

  def test_ast_node_to_review_syntax
    generator = ReVIEW::AST::ReVIEWGenerator.new

    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello world')
    assert_equal 'hello world', generator.generate(text_node)

    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b, args: ['bold text'])
    assert_equal '@<b>{bold text}', generator.generate(inline_node)
  end

  def test_code_block_with_ast_compiler_integration
    source = <<~EOS
      //list[sample][Sample Code]{
      puts @<b>{hello}
      puts "world"
      //}
    EOS

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(source))

    compiler = ReVIEW::AST::Compiler.new
    ast_root = compiler.compile_to_ast(chapter)

    code_block = find_code_block_in_ast(ast_root)
    assert_not_nil(code_block)
    assert_instance_of(ReVIEW::AST::CodeBlockNode, code_block)

    assert_include(code_block.original_text, 'puts @<b>{hello}')
    assert_include(code_block.original_text, 'puts "world"')

    original_lines = code_block.original_lines
    assert_equal 2, original_lines.size
    assert_equal 'puts @<b>{hello}', original_lines[0]
    assert_equal 'puts "world"', original_lines[1]
  end

  def test_render_ast_node_as_plain_text_with_text_node
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello world')

    result = render_ast_node_as_plain_text_helper(text_node)
    assert_equal 'hello world', result
  end

  def test_render_ast_node_as_plain_text_with_inline_node
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'bold text')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(text_node)

    result = render_ast_node_as_plain_text_helper(inline_node)
    assert_equal '@<b>{bold text}', result
  end

  def test_render_ast_node_as_plain_text_with_paragraph_containing_inline
    paragraph = create_test_paragraph

    result = render_ast_node_as_plain_text_helper(paragraph)
    assert_equal 'puts @<b>{hello}', result
  end

  def test_render_ast_node_as_plain_text_with_complex_inline
    bold_text = ReVIEW::AST::TextNode.new(location: @location, content: 'bold')
    bold_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    bold_inline.add_child(bold_text)

    italic_text1 = ReVIEW::AST::TextNode.new(location: @location, content: 'italic ')
    italic_inline = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :i)
    italic_inline.add_child(italic_text1)
    italic_inline.add_child(bold_inline)

    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'This is '))
    paragraph.add_child(italic_inline)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' text'))

    result = render_ast_node_as_plain_text_helper(paragraph)
    assert_equal 'This is @<i>{italic @<b>{bold}} text', result
  end

  def test_code_block_node_inheritance_from_base_node
    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'test content'
    )

    assert_respond_to(code_block, :original_text)
    assert_equal 'test content', code_block.original_text

    assert_respond_to(code_block, :location)
    assert_respond_to(code_block, :children)
    assert_equal @location, code_block.location
  end

  def test_original_text_preservation
    code_block1 = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: 'original content'
    )
    assert_equal 'original content', code_block1.original_text
    assert_equal ['original content'], code_block1.original_lines

    code_block2 = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      original_text: nil
    )
    assert_nil(code_block2.original_text)
    assert_equal [], code_block2.original_lines
  end

  def test_serialize_properties_includes_original_text
    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Test Caption'))

    code_block = ReVIEW::AST::CodeBlockNode.new(
      location: @location,
      id: 'test',
      caption_node: caption_node,
      original_text: 'puts hello'
    )

    hash = {}
    options = ReVIEW::AST::JSONSerializer::Options.new

    assert_nothing_raised do
      code_block.send(:serialize_properties, hash, options)
    end

    assert_equal 'test', hash[:id]
    assert_instance_of(Hash, hash[:caption_node])
    assert_equal 'CaptionNode', hash[:caption_node][:type]
    assert_equal 1, hash[:caption_node][:children].size
    assert_equal 'TextNode', hash[:caption_node][:children][0][:type]
    assert_equal 'Test Caption', hash[:caption_node][:children][0][:content]
  end

  private

  def create_test_paragraph
    text_node = ReVIEW::AST::TextNode.new(location: @location, content: 'hello')
    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: :b)
    inline_node.add_child(text_node)

    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'puts '))
    paragraph.add_child(inline_node)

    paragraph
  end

  def find_code_block_in_ast(node)
    return node if node.is_a?(ReVIEW::AST::CodeBlockNode)

    if node.children
      node.children.each do |child|
        result = find_code_block_in_ast(child)
        return result if result
      end
    end

    nil
  end

  # Helper method to render AST node as plain text (replacement for deleted method)
  def render_ast_node_as_plain_text_helper(node)
    case node
    when ReVIEW::AST::TextNode
      node.content
    when ReVIEW::AST::InlineNode
      content = node.children.map { |child| render_ast_node_as_plain_text_helper(child) }.join
      "@<#{node.inline_type}>{#{content}}"
    when ReVIEW::AST::ParagraphNode
      node.children.map { |child| render_ast_node_as_plain_text_helper(child) }.join
    else
      if node.respond_to?(:children)
        node.children.map { |child| render_ast_node_as_plain_text_helper(child) }.join
      else
        ''
      end
    end
  end
end
