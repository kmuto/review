# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/htmlbuilder'
require 'review/compiler'
require 'review/book'
require 'review/book/chapter'

class TestASTBasic < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_ast_node_creation
    node = ReVIEW::AST::ParagraphNode.new
    assert_equal [], node.children
    assert_nil(node.parent)
    assert_nil(node.location)
  end

  def test_headline_node
    node = ReVIEW::AST::HeadlineNode.new(
      level: 1,
      label: 'test-label',
      caption: ReVIEW::AST::CaptionNode.parse('Test Headline')
    )

    hash = node.to_h
    assert_equal 'HeadlineNode', hash[:type]
    assert_equal 1, hash[:level]
    assert_equal 'test-label', hash[:label]
    assert_equal({ children: [{ content: 'Test Headline', location: nil, type: 'TextNode' }], location: nil, type: 'CaptionNode' }, hash[:caption])
  end

  def test_paragraph_node
    node = ReVIEW::AST::ParagraphNode.new
    text_node = ReVIEW::AST::TextNode.new(content: 'This is a test paragraph.')
    node.add_child(text_node)

    hash = node.to_h
    assert_equal 'ParagraphNode', hash[:type]
    # Check that the text content is in the children
    assert_equal 1, hash[:children].size
    assert_equal 'This is a test paragraph.', hash[:children][0][:content]
  end

  def test_ast_compilation_basic
    chapter_content = <<~EOB
      = Test Chapter

      This is a test paragraph.

      == Section 1

      Another paragraph here.
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = chapter_content

    # Test direct AST compilation using AST classes
    compiler = ReVIEW::AST::Compiler.new
    ast_result = compiler.compile_to_ast(chapter)

    # Verify that AST result is obtained
    assert_not_nil(ast_result)
    assert_equal ReVIEW::AST::DocumentNode, ast_result.class
    assert ast_result.children.any?

    # Convert AST to JSON for verification
    options = ReVIEW::AST::JSONSerializer::Options.new(pretty: true)
    json_result = ReVIEW::AST::JSONSerializer.serialize(ast_result, options)

    parsed = JSON.parse(json_result)
    assert parsed.is_a?(Hash)
    assert_equal 'DocumentNode', parsed['type']
    assert parsed.key?('children')
  end

  def test_json_output_format
    node = ReVIEW::AST::DocumentNode.new
    child_node = ReVIEW::AST::HeadlineNode.new(
      level: 1,
      caption: ReVIEW::AST::CaptionNode.parse('Test')
    )

    node.add_child(child_node)

    json_str = node.to_json
    parsed = JSON.parse(json_str)

    assert_equal 'DocumentNode', parsed['type']
    assert_equal 1, parsed['children'].size
    assert_equal 'HeadlineNode', parsed['children'][0]['type']
    assert_equal 1, parsed['children'][0]['level']
    assert_equal({ 'children' => [{ 'content' => 'Test', 'location' => nil, 'type' => 'TextNode' }], 'location' => nil, 'type' => 'CaptionNode' }, parsed['children'][0]['caption'])
  end
end
