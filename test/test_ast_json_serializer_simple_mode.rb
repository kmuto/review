# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/json_serializer'
require 'review/compiler'
require 'review/builder'
require 'review/book'
require 'review/book/chapter'
require 'json'

# Dummy builder for AST generation in tests
class DummyBuilder < ReVIEW::Builder
  def result
    ''
  end

  def headline(_level, _label, _caption)
    ''
  end

  def paragraph(_lines)
    ''
  end

  def list(_lines, _id, _caption, _lang = nil)
    ''
  end

  def nofunc_text(str)
    str
  end
end

class TestASTJSONSerializerSimpleMode < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_simple_mode_basic_document
    content = <<~EOB
      = Test Chapter

      This is a test paragraph.
    EOB

    ast_root = compile_to_ast(content)

    # Test simple mode
    simple_options = ReVIEW::AST::JSONSerializer::Options.new(
      simple_mode: true,
      include_location: false
    )
    simple_hash = ReVIEW::AST::JSONSerializer.serialize_to_hash(ast_root, simple_options)

    assert_equal 'DocumentNode', simple_hash['type']
    assert simple_hash['content'].is_a?(Array)

    # Check headline
    headline = simple_hash['content'].find { |item| item['type'] == 'HeadlineNode' }
    assert_not_nil(headline)
    assert_equal 1, headline['level']
    assert_equal 'Test Chapter', headline['caption']

    # Check paragraph
    paragraph = simple_hash['content'].find { |item| item['type'] == 'ParagraphNode' }
    assert_not_nil(paragraph)
    assert_equal 'This is a test paragraph.', paragraph['content']
  end

  def test_simple_mode_vs_traditional_mode
    content = <<~EOB
      = Test Chapter

      This has @<b>{bold} text.
    EOB

    ast_root = compile_to_ast(content)

    # Traditional mode
    traditional_options = ReVIEW::AST::JSONSerializer::Options.new(
      simple_mode: false,
      include_location: false
    )
    traditional_hash = ReVIEW::AST::JSONSerializer.serialize_to_hash(ast_root, traditional_options)

    # Simple mode
    simple_options = ReVIEW::AST::JSONSerializer::Options.new(
      simple_mode: true,
      include_location: false
    )
    simple_hash = ReVIEW::AST::JSONSerializer.serialize_to_hash(ast_root, simple_options)

    # Both should be DocumentNode at root
    assert_equal 'DocumentNode', traditional_hash[:type]
    assert_equal 'DocumentNode', simple_hash['type']

    # Simple mode uses strings as keys, traditional uses symbols
    assert traditional_hash.key?(:children) || traditional_hash.key?(:content)
    assert simple_hash.key?('content')
  end

  def test_simple_mode_with_location
    content = <<~EOB
      = Test
    EOB

    ast_root = compile_to_ast(content)

    # Simple mode with location
    options = ReVIEW::AST::JSONSerializer::Options.new(
      simple_mode: true,
      include_location: true
    )
    hash = ReVIEW::AST::JSONSerializer.serialize_to_hash(ast_root, options)

    assert hash.key?('location')
    assert hash['location'].key?('filename')
    assert hash['location'].key?('lineno')
  end

  def test_simple_mode_code_block
    content = <<~EOB
      = Code Test

      //list[sample][Sample Code][ruby]{
      puts "Hello"
      //}
    EOB

    ast_root = compile_to_ast(content)

    options = ReVIEW::AST::JSONSerializer::Options.new(
      simple_mode: true,
      include_location: false
    )
    hash = ReVIEW::AST::JSONSerializer.serialize_to_hash(ast_root, options)

    code_block = hash['content'].find { |item| item['type'] == 'CodeBlockNode' }
    assert_not_nil(code_block)
    assert_equal 'sample', code_block['id']
    assert_equal 'Sample Code', code_block['caption']
    assert_equal 'ruby', code_block['lang']
    assert_equal ['puts "Hello"'], code_block['lines']
  end

  def test_simple_mode_json_output
    content = <<~EOB
      = JSON Test
    EOB

    ast_root = compile_to_ast(content)

    options = ReVIEW::AST::JSONSerializer::Options.new(
      simple_mode: true,
      include_location: false,
      pretty: true
    )
    json_string = ReVIEW::AST::JSONSerializer.serialize(ast_root, options)

    # Verify it's valid JSON
    parsed = JSON.parse(json_string)
    assert_equal 'DocumentNode', parsed['type']
  end

  private

  def compile_to_ast(content)
    builder = DummyBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler.compile(chapter)
    compiler.ast_result
  end
end
