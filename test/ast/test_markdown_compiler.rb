# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/markdown_compiler'
require 'review/ast/node'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'stringio'

class TestMarkdownCompiler < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new(config: @config)
    @compiler = ReVIEW::AST::MarkdownCompiler.new
  end

  def create_chapter(content)
    ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.md', StringIO.new(content))
  end

  def test_heading_conversion
    markdown = <<~MD
      # Chapter Title
      
      ## Section 1.1
      
      ### Subsection 1.1.1
      
      #### Level 4
      
      ##### Level 5
      
      ###### Level 6
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    assert_kind_of(ReVIEW::AST::DocumentNode, ast)

    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal 6, headlines.size

    assert_equal 1, headlines[0].level
    assert_equal 'Chapter Title', headlines[0].caption_node.children.first.content

    assert_equal 2, headlines[1].level
    assert_equal 'Section 1.1', headlines[1].caption_node.children.first.content

    assert_equal 3, headlines[2].level
    assert_equal 4, headlines[3].level
    assert_equal 5, headlines[4].level
    assert_equal 6, headlines[5].level
  end

  def test_paragraph_conversion
    markdown = <<~MD
      This is a paragraph.
      
      This is another paragraph with **bold** and *italic* text.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    paragraphs = ast.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paragraphs.size

    # First paragraph
    assert_equal 'This is a paragraph.', paragraphs[0].children.first.content

    # Second paragraph with inline elements
    para2_children = paragraphs[1].children
    assert_equal 'This is another paragraph with ', para2_children[0].content
    assert_kind_of(ReVIEW::AST::InlineNode, para2_children[1])
    assert_equal :b, para2_children[1].inline_type
    assert_equal ' and ', para2_children[2].content
    assert_kind_of(ReVIEW::AST::InlineNode, para2_children[3])
    assert_equal :i, para2_children[3].inline_type
  end

  def test_list_conversion
    markdown = <<~MD
      ## Lists
      
      * Item 1
      * Item 2
        * Nested item
      * Item 3
      
      1. First
      2. Second
      3. Third
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 2, lists.size

    # Unordered list
    ul = lists[0]
    assert_kind_of(ReVIEW::AST::ListNode, ul)
    assert ul.ul?
    assert_equal 3, ul.children.size

    # Check first item
    assert_kind_of(ReVIEW::AST::ListItemNode, ul.children[0])
    assert_equal 'Item 1', ul.children[0].children.first.content

    # Ordered list
    ol = lists[1]
    assert_kind_of(ReVIEW::AST::ListNode, ol)
    assert ol.ol?
    assert_equal 3, ol.children.size
    assert_equal 1, ol.start_number
  end

  def test_code_block_conversion
    markdown = <<~MD
      ```ruby
      def hello
        puts "Hello, World!"
      end
      ```
      
      ```
      Plain code block
      ```
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    code_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_equal 2, code_blocks.size

    # Ruby code block
    ruby_block = code_blocks[0]
    assert_equal 'ruby', ruby_block.lang
    assert_equal :emlist, ruby_block.code_type
    assert_equal 3, ruby_block.children.size
    assert_equal 'def hello', ruby_block.children[0].children.first.content

    # Plain code block
    plain_block = code_blocks[1]
    assert_nil(plain_block.lang)
  end

  def test_blockquote_conversion
    markdown = <<~MD
      > This is a quote.
      > 
      > With multiple lines.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    quotes = ast.children.select { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :quote }
    assert_equal 1, quotes.size

    quote = quotes[0]
    paragraphs = quote.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paragraphs.size
  end

  def test_inline_code_conversion
    markdown = 'Use `code` inline.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    para = ast.children.first
    assert_kind_of(ReVIEW::AST::ParagraphNode, para)

    inline_code = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :code }
    assert_not_nil(inline_code)
    assert_equal 'code', inline_code.args[0]
  end

  def test_link_conversion
    markdown = 'Visit [Example](https://example.com) for more info.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    para = ast.children.first
    link = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :href }
    assert_not_nil(link)
    assert_equal 'https://example.com', link.args[0]
    assert_equal 'Example', link.args[1]
  end

  def test_image_conversion
    markdown = '![Alt text](image.png)'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # Standalone images are now processed as ImageNode instead of inline icon
    image = ast.children.find { |n| n.is_a?(ReVIEW::AST::ImageNode) }
    assert_not_nil(image)
    assert_equal 'image', image.id
    assert_equal 'Alt text', image.caption_node.children.first.content
  end

  def test_inline_image_conversion
    markdown = 'This is text with ![inline image](icon.png) in the middle.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # Inline images (not standalone) should still be processed as icon
    para = ast.children.first
    image = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :icon }
    assert_not_nil(image)
    assert_equal 'icon.png', image.args[0]
  end

  def test_table_conversion
    markdown = <<~MD
      | Header 1 | Header 2 |
      |----------|----------|
      | Cell 1   | Cell 2   |
      | Cell 3   | Cell 4   |
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    tables = ast.children.select { |n| n.is_a?(ReVIEW::AST::TableNode) }
    assert_equal 1, tables.size

    table = tables[0]
    rows = table.children
    assert_equal 3, rows.size # Header + 2 body rows

    # Check header row
    header_row = rows[0]
    assert_equal :header, header_row.row_type
    assert_equal 2, header_row.children.size

    # Check body rows
    assert_equal :body, rows[1].row_type
    assert_equal :body, rows[2].row_type
  end

  def test_strikethrough_conversion
    markdown = 'This is ~~strikethrough~~ text.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    para = ast.children.first
    del = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :del }
    assert_not_nil(del)
    assert_equal 'strikethrough', del.args[0]
  end

  def test_horizontal_rule_conversion
    markdown = <<~MD
      Text before
      
      ---
      
      Text after
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    hr = ast.children.find { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :hr }
    assert_not_nil(hr)
  end

  def test_complex_document
    markdown = <<~MD
      # Main Title
      
      This is the introduction with **bold** and *italic* text.
      
      ## Features
      
      * Feature 1 with `inline code`
      * Feature 2 with [link](https://example.com)
      * Feature 3
      
      ### Code Example
      
      ```ruby
      class Example
        def initialize
          @value = 42
        end
      end
      ```
      
      ## Conclusion
      
      > This is a famous quote.
      > 
      > -- Author
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # Verify overall structure
    assert_kind_of(ReVIEW::AST::DocumentNode, ast)
    assert ast.children.size > 0

    # Count different node types
    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    paragraphs = ast.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) && n.ul? }
    code_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    quotes = ast.children.select { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :quote }

    assert_equal 4, headlines.size # Main Title, Features, Code Example, Conclusion
    assert_equal 1, paragraphs.size  # Introduction
    assert_equal 1, lists.size       # Feature list
    assert_equal 1, code_blocks.size # Ruby code
    assert_equal 1, quotes.size      # Famous quote
  end
end
