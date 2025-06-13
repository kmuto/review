# frozen_string_literal: true

require File.expand_path('test_helper', __dir__)
require 'review/ast'
require 'review/jsonbuilder'
require 'review/compiler'
require 'review/book'
require 'review/book/chapter'

class TestASTBasic < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new
    @book.config = @config
  end

  def test_ast_node_creation
    node = ReVIEW::AST::Node.new
    assert_equal [], node.children
    assert_nil(node.parent)
    assert_nil(node.location)
  end

  def test_headline_node
    node = ReVIEW::AST::HeadlineNode.new
    node.level = 1
    node.label = 'test-label'
    node.caption = 'Test Headline'

    hash = node.to_h
    assert_equal 'HeadlineNode', hash[:type]
    assert_equal 1, hash[:level]
    assert_equal 'test-label', hash[:label]
    assert_equal 'Test Headline', hash[:caption]
  end

  def test_paragraph_node
    node = ReVIEW::AST::ParagraphNode.new
    node.content = 'This is a test paragraph.'

    hash = node.to_h
    assert_equal 'ParagraphNode', hash[:type]
    assert_equal 'This is a test paragraph.', hash[:content]
  end

  def test_json_builder_basic
    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)

    chapter_content = <<~EOB
      = Test Chapter

      This is a test paragraph.

      == Section 1

      Another paragraph here.
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = chapter_content

    # Execute compilation
    result = compiler.compile(chapter)

    # Verify that JSON format result is obtained
    assert result.is_a?(String)

    # Verify that it can be parsed as JSON
    parsed = JSON.parse(result)
    assert parsed.is_a?(Hash)
    assert_equal 'DocumentNode', parsed['type']
    assert parsed.key?('children')
  end

  def test_json_output_format
    node = ReVIEW::AST::DocumentNode.new
    child_node = ReVIEW::AST::HeadlineNode.new
    child_node.level = 1
    child_node.caption = 'Test'

    node.add_child(child_node)

    json_str = node.to_json
    parsed = JSON.parse(json_str)

    assert_equal 'DocumentNode', parsed['type']
    assert_equal 1, parsed['children'].size
    assert_equal 'HeadlineNode', parsed['children'][0]['type']
    assert_equal 1, parsed['children'][0]['level']
    assert_equal 'Test', parsed['children'][0]['caption']
  end
end
