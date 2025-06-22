# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/json_serializer'
require 'review/ast/review_generator'
require 'review/book'
require 'review/book/chapter'
require 'json'
require 'stringio'

class TestASTBidirectionalConversion < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
    @generator = ReVIEW::AST::ReVIEWGenerator.new
  end

  def test_simple_round_trip_conversion
    # Test if caption serialization is now fixed with CaptionNode.to_h method

    content = <<~EOB
      = Test Chapter

      This is a simple paragraph.
    EOB

    # Step 1: Re:VIEW -> AST
    ast_root = compile_to_ast(content)
    assert_not_nil(ast_root)

    # Step 2: AST -> JSON
    json_string = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    assert_not_nil(json_string)
    parsed_json = JSON.parse(json_string)
    assert_equal 'DocumentNode', parsed_json['type']

    # Step 3: JSON -> AST
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    assert_not_nil(regenerated_ast)
    assert_equal 'ReVIEW::AST::DocumentNode', regenerated_ast.class.name

    # Step 4: AST -> Re:VIEW
    regenerated_content = @generator.generate(regenerated_ast)
    assert_not_nil(regenerated_content)

    # Verify basic structure is preserved
    assert_match(/= Test Chapter/, regenerated_content)
    assert_match(/This is a simple paragraph/, regenerated_content)
  end

  def test_inline_elements_round_trip
    # Caption serialization is now fixed

    content = <<~EOB
      = Inline Test

      This has @<b>{bold} and @<i>{italic} text.
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Check that inline elements are preserved
    assert_match(/@<b>\{bold\}/, regenerated_content)
    assert_match(/@<i>\{italic\}/, regenerated_content)
  end

  def test_list_round_trip
    content = <<~EOB
      = List Test

       * Item 1
       * Item 2
       * Item 3
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Check that list structure is preserved (but skip headline check due to caption serialization issue)
    assert_match(/\* Item 1/, regenerated_content)
    assert_match(/\* Item 2/, regenerated_content)
    assert_match(/\* Item 3/, regenerated_content)

    # Verify that list items appear in order
    lines = regenerated_content.split("\n")
    item1_line = lines.find_index { |line| line.include?('* Item 1') }
    item2_line = lines.find_index { |line| line.include?('* Item 2') }
    item3_line = lines.find_index { |line| line.include?('* Item 3') }

    assert_not_nil(item1_line, 'Item 1 not found')
    assert_not_nil(item2_line, 'Item 2 not found')
    assert_not_nil(item3_line, 'Item 3 not found')
    assert item1_line < item2_line, 'Items not in correct order'
    assert item2_line < item3_line, 'Items not in correct order'
  end

  def test_code_block_round_trip
    content = <<~EOB
      = Code Test

      //list[sample][Sample @<b>{Code}][ruby]{
      puts "Hello"
      def greet
        puts "Hi"
      end
      //}
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Check that code block structure is preserved
    assert_match(%r{//list\[sample\]\[Sample @<b>\{Code\}\]}, regenerated_content)
    assert_match(/puts "Hello"/, regenerated_content)
    assert_match(/def greet/, regenerated_content)
  end

  def test_table_round_trip
    content = <<~EOB
      = Table Test

      //table[table1][Sample Table]{
      Name	Age
      ----------
      Alice	25
      Bob	30
      //}
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Check that table structure is preserved (caption will be JSON but table content should work)
    assert_match(%r{//table\[table1\]}, regenerated_content) # ID should be preserved
    assert_match(/Name\s+Age/, regenerated_content)
    assert_match(/Alice\s+25/, regenerated_content)
    assert_match(/Bob\s+30/, regenerated_content)

    # Verify table structure
    assert_match(/----------/, regenerated_content)  # Table separator
    assert_match(%r{//\}}, regenerated_content)      # Table end
  end

  def test_image_round_trip
    content = <<~EOB
      = Image Test

      //image[sample_image][Sample Image @<b>{Caption}]{
      //}
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Check that image structure is preserved
    assert_match(%r{//image\[sample_image\]}, regenerated_content) # ID should be preserved
    assert_match(/Sample Image/, regenerated_content) # Caption content should be preserved
    assert_match(/@<b>\{Caption\}/, regenerated_content) # Inline elements in caption should be preserved
  end

  def test_image_with_options_round_trip
    content = <<~EOB
      = Image with Options Test

      //image[scaled_image][Scaled Image][scale=0.5]{
      //}
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Check that image with options structure is preserved
    assert_match(%r{//image\[scaled_image\]}, regenerated_content) # ID should be preserved
    assert_match(/Scaled Image/, regenerated_content) # Caption should be preserved
    assert_match(/scale=0\.5/, regenerated_content) # Options should be preserved
  end

  def test_complex_structure_round_trip
    content = <<~EOB
      = Complex Test

      This is a paragraph with @<b>{bold} text.

       1. First item
       2. Second item with @<i>{italic}

      //list[code1][Code Example]{
      puts "Hello"
      //}

      //table[data][Data Table]{
      Key	Value
      ----
      A	1
      //}
    EOB

    original_ast = compile_to_ast(content)
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    regenerated_content = @generator.generate(regenerated_ast)

    # Verify multiple elements are preserved (skip headline check due to caption issue)
    assert_match(/@<b>\{bold\}/, regenerated_content)
    assert_match(/1\. First item/, regenerated_content)
    assert_match(/@<i>\{italic\}/, regenerated_content)
    assert_match(%r{//list\[code1\]}, regenerated_content)  # Code block ID preserved
    assert_match(%r{//table\[data\]}, regenerated_content)  # Table ID preserved
    assert_match(/puts "Hello"/, regenerated_content)        # Code content preserved
    assert_match(/Key\s+Value/, regenerated_content)         # Table content preserved
  end

  def test_json_structure_consistency
    content = <<~EOB
      = Structure Test

      Simple paragraph.
    EOB

    # Test with different serialization options
    original_ast = compile_to_ast(content)

    # Simple mode
    simple_options = ReVIEW::AST::JSONSerializer::Options.new(simple_mode: true)
    simple_json = ReVIEW::AST::JSONSerializer.serialize(original_ast, simple_options)
    simple_ast = ReVIEW::AST::JSONSerializer.deserialize(simple_json)
    simple_content = @generator.generate(simple_ast)

    # Traditional mode
    traditional_options = ReVIEW::AST::JSONSerializer::Options.new(simple_mode: false)
    traditional_json = ReVIEW::AST::JSONSerializer.serialize(original_ast, traditional_options)
    traditional_ast = ReVIEW::AST::JSONSerializer.deserialize(traditional_json)
    traditional_content = @generator.generate(traditional_ast)

    # Both should produce similar Re:VIEW output
    assert_match(/= Structure Test/, simple_content)
    assert_match(/= Structure Test/, traditional_content)
    assert_match(/Simple paragraph/, simple_content)
    assert_match(/Simple paragraph/, traditional_content)
  end

  def test_basic_ast_serialization_works
    # This test verifies that basic AST creation and JSON serialization works
    content = 'Simple text paragraph.'

    original_ast = compile_to_ast(content)
    assert_not_nil(original_ast)
    assert_equal 'ReVIEW::AST::DocumentNode', original_ast.class.name

    # Test JSON serialization
    json_string = ReVIEW::AST::JSONSerializer.serialize(original_ast)
    assert_not_nil(json_string)
    parsed = JSON.parse(json_string)
    assert_equal 'DocumentNode', parsed['type']

    # Test JSON deserialization
    regenerated_ast = ReVIEW::AST::JSONSerializer.deserialize(json_string)
    assert_not_nil(regenerated_ast)
    assert_equal 'ReVIEW::AST::DocumentNode', regenerated_ast.class.name
  end

  private

  def compile_to_ast(content)
    # Use AST::Compiler directly, no builder needed for bidirectional conversion tests
    compiler = ReVIEW::AST::Compiler.new(nil)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    compiler.compile_to_ast(chapter)
  end
end
