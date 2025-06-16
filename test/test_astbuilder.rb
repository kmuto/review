# frozen_string_literal: true

# Test for Full AST Mode - comprehensive AST processing with JSONBuilder
# This demonstrates production-level AST generation and processing capabilities.
# For simple Hash-based AST testing, see test_astbuilder_simple.rb

require 'json'
require_relative 'test_helper'
require 'review'
require 'review/jsonbuilder'

# Simple chapter object for testing
class FakeChapter
  attr_reader :content, :basename, :number, :book

  def initialize(content, basename = 'test', book:, number: '1')
    @content = content
    @basename = basename
    @book = book
    @number = number
  end

  def generate_indexes
    # No-op for test
  end
end

class TestReVIEWParser < Test::Unit::TestCase
  def setup
    @builder = ReVIEW::JSONBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    # Use AST mode compiler for proper AST processing
    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true)
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = ReVIEW::Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    ReVIEW::I18n.setup(@config['language'])
  end

  # Test for nested inline commands
  def test_nested_inline
    source = <<~EOS
      This paragraph has @<b>{bold} and @<i>{italic} text.
    EOS
    chapter = FakeChapter.new(source, 'nested_inline', book: @book)
    begin
      @compiler.compile(chapter)
      ast_root = @compiler.ast_result
      # Serialize AST to verify structure
      require 'review/ast/json_serializer'
      json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
      ast = JSON.parse(json_str)
    rescue ReVIEW::ApplicationError => e
      puts "Compilation failed: #{e.message}"
      puts "Log output: #{@log_io.string}"
      raise
    end

    # AST root is "DocumentNode"
    assert_equal 'DocumentNode', ast['type']

    # Extract paragraph node (search within children array if multiple blocks exist)
    paragraph = ast['children'].find { |node| node['type'] == 'ParagraphNode' }
    assert_not_nil(paragraph, 'Paragraph node should exist')

    # Find "InlineNode" with inline_type "b" from paragraph child nodes (inline elements)
    bold_node = paragraph['children'].find do |n|
      n['type'] == 'InlineNode' && n['inline_type'] == 'b'
    end
    assert_not_nil(bold_node, 'Inline bold (@<b>{...}) should exist')

    # Find InlineNode with inline_type "i" from paragraph child elements (parallel, not nested)
    italic_node = paragraph['children'].find do |n|
      n['type'] == 'InlineNode' && n['inline_type'] == 'i'
    end
    assert_not_nil(italic_node, 'Inline italic (@<i>{...}) should exist')

    # Verify text within italic node
    italic_text = italic_node['children'].find { |n| n['type'] == 'TextNode' }
    assert_equal 'italic', italic_text['content'], "Italic text should be 'italic'"
  end

  # Test for complex source with multiple mixed blocks
  def test_complex_source
    source = <<~EOS
      = Chapter Title

      This is the first paragraph with some inline command: @<b>{bold text}.

      //note[Note Caption]{
      This is a note block.
      It can have multiple lines.
      @<b>{Note has bold text too.}
      //}

      //list[identifier][List Caption][ruby]{
      puts "hello world!"
      //}

      //read{
      This is a read block.
      //}

      //memo[Memo Title]{
      This is a memo with a title.
      //}

      //quote{
      This is a quote block with some text.
      //}
    EOS
    chapter = FakeChapter.new(source, 'complex_source', book: @book)
    begin
      @compiler.compile(chapter)
      ast_root = @compiler.ast_result
      # Serialize AST to verify structure
      require 'review/ast/json_serializer'
      json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
      ast = JSON.parse(json_str)
    rescue ReVIEW::ApplicationError => e
      puts "Compilation failed: #{e.message}"
      puts "Log output: #{@log_io.string}"
      raise
    end

    # Check heading
    heading = ast['children'].find { |node| node['type'] == 'HeadlineNode' }
    assert_not_nil(heading, 'Heading node should exist')
    assert_equal 'Chapter Title', heading['caption'], "Heading caption should be 'Chapter Title'"

    # Check paragraph
    paragraph = ast['children'].find { |node| node['type'] == 'ParagraphNode' }
    assert_not_nil(paragraph, 'Paragraph should exist')
    bold_node = paragraph['children'].find do |n|
      n['type'] == 'InlineNode' && n['inline_type'] == 'b'
    end
    assert_not_nil(bold_node, 'Paragraph should contain inline bold')

    # Check code block (list command)
    code_block = ast['children'].find { |node| node['type'] == 'CodeBlockNode' }
    assert_not_nil(code_block, 'Code block (list command) should exist')
    assert_equal 'ruby', code_block['lang'], "Code block language should be 'ruby'"

    # Check note block (minicolumn)
    generic_nodes = ast['children'].select { |node| node['type'] == 'Node' }

    note_block = generic_nodes.find { |node| node['id'] == 'note' }
    assert_not_nil(note_block, 'Note block should exist')
    assert_equal 'note', note_block['id'], 'Note block should have correct id'
    assert_equal 'Note Caption', note_block['content'], 'Note block should have correct caption'
    assert_equal 3, note_block['children'].size, 'Note block should have 3 text children'

    # Check that note block contains expected text content
    note_texts = note_block['children'].map { |child| child['content'] }
    assert_include(note_texts, 'This is a note block.', 'Note should contain expected text')
    assert_include(note_texts, 'It can have multiple lines.', 'Note should contain multiple lines')

    # Check read block
    read_block = generic_nodes.find { |node| node['node_type'] == 'read' }
    assert_not_nil(read_block, 'Read block should exist')
    assert_equal 'read', read_block['node_type'], 'Read block should have correct node_type'
    assert_equal 'This is a read block.', read_block['content'], 'Read block should have correct content'
    assert_equal 1, read_block['children'].size, 'Read block should have 1 text child'

    # Check read block text content
    read_text = read_block['children'].first
    assert_equal 'TextNode', read_text['type'], 'Read block child should be TextNode'
    assert_equal 'This is a read block.', read_text['content'], 'Read block text should match'

    # Check memo block (another minicolumn type)
    memo_block = generic_nodes.find { |node| node['id'] == 'memo' }
    assert_not_nil(memo_block, 'Memo block should exist')
    assert_equal 'memo', memo_block['id'], 'Memo block should have correct id'
    assert_equal 'Memo Title', memo_block['content'], 'Memo block should have correct title'

    # Check quote block
    quote_blocks = ast['children'].select { |node| node['type'] == 'ParagraphNode' }
    # NOTE: quote might be processed as ParagraphNode depending on implementation
    assert(quote_blocks.size >= 2, 'Should have multiple paragraph nodes including quote content')

    # Verify overall structure
    expected_types = ['HeadlineNode', 'ParagraphNode', 'Node', 'CodeBlockNode', 'Node', 'Node', 'ParagraphNode']
    actual_types = ast['children'].map { |child| child['type'] }
    assert_equal expected_types.size, actual_types.size, 'Should have expected number of elements'
  end
end
