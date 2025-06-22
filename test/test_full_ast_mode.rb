# frozen_string_literal: true

# Test for Full AST Mode - comprehensive AST processing with Pure AST Mode
# This demonstrates production-level AST generation and processing capabilities.

require 'json'
require_relative 'test_helper'
require 'review'
require 'review/htmlbuilder'
require 'review/book'
require 'review/book/chapter'

# Use real Chapter class for proper testing

class TestFullASTMode < Test::Unit::TestCase
  def setup
    @builder = ReVIEW::HTMLBuilder.new
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
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'nested_inline', 'nested_inline.re', StringIO.new)
    chapter.content = source
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
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'complex_source', 'complex_source.re', StringIO.new)
    chapter.content = source
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

    # Caption is now a CaptionNode with children
    assert_equal 'CaptionNode', heading['caption']['type'], 'Caption should be a CaptionNode'
    caption_markup_text = heading['caption']['children'].first
    assert_equal 'TextNode', caption_markup_text['type'], 'Caption should contain a TextNode'
    assert_equal 'Chapter Title', caption_markup_text['content'], "Caption text should be 'Chapter Title'"

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
    minicolumn_nodes = ast['children'].select { |node| node['type'] == 'MinicolumnNode' }

    note_block = minicolumn_nodes.find { |node| node['minicolumn_type'] == 'note' }
    assert_not_nil(note_block, 'Note block should exist')
    assert_equal 'note', note_block['minicolumn_type'], 'Note block should have correct minicolumn_type'

    # Check caption
    assert_not_nil(note_block['caption'], 'Note block should have caption')
    caption_text = note_block['caption']['children'].first['content']
    assert_equal 'Note Caption', caption_text, 'Note block should have correct caption'

    assert_equal 3, note_block['children'].size, 'Note block should have 3 text children'

    # Check that note block contains expected text content
    note_texts = note_block['children'].map { |child| child['content'] }
    assert_include(note_texts, 'This is a note block.', 'Note should contain expected text')
    assert_include(note_texts, 'It can have multiple lines.', 'Note should contain multiple lines')

    # Check read block
    block_nodes = ast['children'].select { |node| node['type'] == 'BlockNode' }
    read_block = block_nodes.find { |node| node['block_type'] == 'read' }
    assert_not_nil(read_block, 'Read block should exist')
    assert_equal 'read', read_block['block_type'], 'Read block should have correct block_type'
    assert_equal 1, read_block['children'].size, 'Read block should have 1 text child'

    # Check read block text content
    read_text = read_block['children'].first
    assert_equal 'TextNode', read_text['type'], 'Read block child should be TextNode'
    assert_equal 'This is a read block.', read_text['content'], 'Read block text should match'

    # Check memo block (another minicolumn type)
    memo_block = minicolumn_nodes.find { |node| node['minicolumn_type'] == 'memo' }
    assert_not_nil(memo_block, 'Memo block should exist')
    assert_equal 'memo', memo_block['minicolumn_type'], 'Memo block should have correct minicolumn_type'

    # Check memo caption
    memo_caption_text = memo_block['caption']['children'].first['content']
    assert_equal 'Memo Title', memo_caption_text, 'Memo block should have correct title'

    # Check quote block
    quote_block = block_nodes.find { |node| node['block_type'] == 'quote' }
    assert_not_nil(quote_block, 'Quote block should exist')
    assert_equal 'quote', quote_block['block_type'], 'Quote block should have correct block_type'

    # Verify overall structure - updated for new node types
    expected_types = ['HeadlineNode', 'ParagraphNode', 'MinicolumnNode', 'CodeBlockNode', 'BlockNode', 'MinicolumnNode', 'BlockNode']
    actual_types = ast['children'].map { |child| child['type'] }
    assert_equal expected_types.size, actual_types.size, 'Should have expected number of elements'
  end
end
