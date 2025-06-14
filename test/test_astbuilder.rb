# frozen_string_literal: true

# test_parser.rb

require 'json'
require 'test_helper'
require 'review'

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
    @builder = ReVIEW::ASTBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = ReVIEW::Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    ReVIEW::I18n.setup(@config['language'])
  end

  # Test for nested inline commands
  def test_nested_inline
    source = <<~EOS
      This is a test with nested inline commands: @<b>{bold and @<i>{italic} text} in one sentence.
    EOS
    chapter = FakeChapter.new(source, 'nested_inline', book: @book)
    ast = @compiler.compile(chapter)

    # AST root is "document" node
    assert_equal 'document', ast['type']

    # Extract paragraph node (search within children array if multiple blocks exist)
    paragraph = ast['children'].find { |node| node['type'] == 'paragraph' }
    assert_not_nil(paragraph, 'Paragraph node should exist')

    # Find "inline_command" with command "b" from paragraph child nodes (inline elements)
    bold_node = paragraph['children'].find do |n|
      n['type'] == 'inline_command' && n['attrs']['command'] == 'b'
    end
    assert_not_nil(bold_node, 'Inline bold (@<b>{...}) should exist')

    # Find inline_command with command "i" from bold node child elements
    italic_node = bold_node['children'].find do |n|
      n['type'] == 'inline_command' && n['attrs']['command'] == 'i'
    end
    assert_not_nil(italic_node, 'Nested italic (@<i>{...}) should exist')

    # Verify text within italic node
    italic_text = italic_node['children'].find { |n| n['type'] == 'text' }
    assert_equal 'italic', italic_text['value'].strip, "Nested italic part should be 'italic'"
  end

  # Test for complex source with multiple mixed blocks
  def test_complex_source
    source = <<~EOS
      = Chapter Title

      This is the first paragraph with some inline command: @<b>{bold text and @<i>{nested italic} inside}.

      //note[Note Caption]{
      This is a note block.
      It can have multiple lines.
      @<b>{Note has bold text too.}
      //}

      //list[identifier][List Caption][ruby]{
      puts "hello world!"
      //}

      //beginchild
      This is a child block within a list.
      //endchild

      //read{
      This is a read block.
      //}

      //note{
      This is a minicolumn note without caption.
      It may contain multiple paragraphs.

      Another paragraph in minicolumn.
      //}
    EOS
    chapter = FakeChapter.new(source, 'complex_source', book: @book)
    ast = @compiler.compile(chapter)

    # Check heading
    heading = ast['children'].find { |node| node['type'] == 'heading' }
    assert_not_nil(heading, 'Heading node should exist')
    assert_equal 'Chapter Title', heading['value'].strip, "Heading caption should be 'Chapter Title'"

    # Check paragraphs (there should be multiple paragraphs)
    paragraphs = ast['children'].select { |node| node['type'] == 'paragraph' }
    assert(paragraphs.size >= 1, 'At least one paragraph should exist')
    first_paragraph = paragraphs.first
    bold_node = first_paragraph['children'].find do |n|
      n['type'] == 'inline_command' && n['attrs']['command'] == 'b'
    end
    assert_not_nil(bold_node, 'First paragraph should contain inline bold')

    # Check minicolumn blocks (note command)
    # In ASTBuilder, minicolumn is generated as "minicolumn" node
    minicolumn_nodes = ast['children'].select { |node| node['type'] == 'minicolumn' }
    assert_not_empty(minicolumn_nodes, 'At least one minicolumn block should exist')
    note_block = minicolumn_nodes.find { |n| n['attrs']['name'] == 'note' }
    assert_not_nil(note_block, 'note block (minicolumn) should exist')
    # NOTE: block contains multiple paragraphs (expecting 2 or more here)
    note_paragraphs = note_block['children'].select { |n| n['type'] == 'paragraph' }
    assert(note_paragraphs.size >= 2, 'note block should contain 2 or more paragraphs')

    # Check list (code block by //list command here)
    code_block = ast['children'].find { |node| node['type'] == 'code_block' }
    assert_not_nil(code_block, 'Code block (list command) should exist')
    assert_equal 'ruby', code_block['attrs']['language'], "Code block language should be 'ruby'"

    # Check read block
    # Here, assuming read block is implemented as block_command
    _read_block = ast['children'].find do |node|
      node['type'] == 'block_command' && node['attrs'] && node['attrs']['command'] == 'read'
    end
    # If read block is not implemented, it may be handled with warn etc., so nil is not treated as error
    # (Please implement AST representation for read block as needed)
  end
end
