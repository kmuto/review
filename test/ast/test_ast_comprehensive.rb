# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/html_renderer'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestASTComprehensive < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_code_blocks_ast_processing
    content = <<~EOB
      = Code Examples

      Normal list with ID:

      //list[sample][Sample Code][ruby]{
      puts "Hello, World!"
      def greeting
        "Hello"
      end
      //}

      Embedded list without ID:

      //emlist[Ruby Example][ruby]{
      puts "Embedded example"
      //}

      Numbered list:

      //listnum[numbered][Numbered Example][python]{
      print("Hello")
      print("World")
      //}

      Command example:

      //cmd[Terminal Commands]{
      ls -la
      cd /home
      //}
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    # Use AST::Compiler directly
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    # Check code block nodes
    code_blocks = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_equal 4, code_blocks.size

    # Check list block
    list_block = code_blocks.find { |n| n.id == 'sample' }
    assert_not_nil(list_block)
    assert_equal 'Sample Code', list_block.caption_markup_text
    assert_equal 'ruby', list_block.lang
    assert_equal false, list_block.line_numbers

    # Check emlist block
    emlist_block = code_blocks.find { |n| n.caption_markup_text == 'Ruby Example' && n.id.nil? }
    assert_not_nil(emlist_block)
    assert_equal 'ruby', emlist_block.lang

    # Check listnum block
    listnum_block = code_blocks.find { |n| n.id == 'numbered' }
    assert_not_nil(listnum_block)
    assert_equal true, listnum_block.line_numbers

    # Check cmd block
    cmd_block = code_blocks.find { |n| n.lang == 'shell' }
    assert_not_nil(cmd_block)
    assert_equal 'Terminal Commands', cmd_block.caption_markup_text
  end

  def test_table_ast_processing
    content = <<~EOB
      = Tables

      //table[envvars][Environment Variables]{
      Name	Meaning
      ------------
      PATH	Command directories
      HOME	User home directory
      LANG	Default locale
      //}

      //emtable[Simple Table]{
      Col1	Col2
      A	B
      C	D
      //}
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    # Use AST::Compiler directly
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    # Check table nodes
    table_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::TableNode) }
    assert_equal 2, table_nodes.size # Both table and emtable are processed via AST

    # Check first table with headers
    main_table = table_nodes.find { |n| n.id == 'envvars' }
    assert_not_nil(main_table)
    assert_equal 'Environment Variables', main_table.caption_markup_text
    assert_equal 1, main_table.header_rows.size
    assert_equal 3, main_table.body_rows.size

    # Check emtable (no headers) - currently processes as traditional
    # since emtable not in AST elements list for this test
  end

  def test_image_ast_processing
    content = <<~EOB
      = Images

      //image[diagram][System Diagram][scale=0.5]{
      ASCII art or description here
      //}

      //indepimage[logo][Company Logo]

    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    # Use AST::Compiler directly
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    # Check image nodes
    image_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ImageNode) }
    assert_equal 2, image_nodes.size

    # Check main image
    main_image = image_nodes.find { |n| n.id == 'diagram' }
    assert_not_nil(main_image)
    assert_equal 'System Diagram', main_image.caption_markup_text
    assert_equal 'scale=0.5', main_image.metric

    # Check indepimage
    indep_image = image_nodes.find { |n| n.id == 'logo' }
    assert_not_nil(indep_image)
    assert_equal 'Company Logo', indep_image.caption_markup_text
  end

  def test_special_inline_elements_ast_processing
    content = <<~EOB
      = Special Inline Elements

      This paragraph contains @<ruby>{漢字,かんじ} with ruby annotation.

      Visit @<href>{https://example.com, Example Site} for more information.

      The @<kw>{HTTP, HyperText Transfer Protocol} is a protocol.

      Simple @<b>{bold} and @<code>{code} elements.

      Unicode character: @<uchar>{2603} (snowman).
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    # Use AST::Compiler directly
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    # Find ruby inline
    ruby_para = paragraph_nodes[0]
    ruby_node = ruby_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :ruby }
    assert_not_nil(ruby_node)
    assert_equal ['漢字', 'かんじ'], ruby_node.args

    # Find href inline
    href_para = paragraph_nodes[1]
    href_node = href_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :href }
    assert_not_nil(href_node)
    assert_equal ['https://example.com', 'Example Site'], href_node.args

    # Find kw inline
    kw_para = paragraph_nodes[2]
    kw_node = kw_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :kw }
    assert_not_nil(kw_node)
    assert_equal ['HTTP', 'HyperText Transfer Protocol'], kw_node.args

    # Find standard inline elements
    simple_para = paragraph_nodes[3]
    bold_node = simple_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :b }
    code_node = simple_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :code }
    assert_not_nil(bold_node)
    assert_not_nil(code_node)

    # Find uchar inline
    uchar_para = paragraph_nodes[4]
    uchar_node = uchar_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :uchar }
    assert_not_nil(uchar_node)
    assert_equal ['2603'], uchar_node.args
  end

  def test_comprehensive_output_compatibility
    content = <<~EOB
      = Comprehensive Test

      Intro with @<b>{bold} text.

       * List item with @<code>{code}
       * Another item

      //list[example][Code Example]{
      puts "Hello"
      //}

      //table[data][Data Table]{
      Name	Value
      ------------
      A	1
      B	2
      //}

      Text with @<ruby>{日本語,にほんご} and @<href>{http://example.com}.

       1. Numbered item
       2. Another numbered item

      //quote{
      This is a quote with @<i>{italic} text.
      //}

      Final paragraph.
    EOB

    # Test with AST/Renderer system
    chapter_ast = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_ast.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter_ast)

    # Render to HTML using HtmlRenderer
    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter_ast)
    result_ast = renderer.render(ast_root)

    # Verify AST/Renderer system produces comprehensive HTML
    ['<h1>', '<ul>', '<ol>', '<table>', '<blockquote>'].each do |tag|
      assert(result_ast.include?(tag), "AST/Renderer system should produce #{tag}")
    end

    # Check inline elements
    ['<b>', '<code', '<i>'].each do |tag|
      assert(result_ast.include?(tag), "AST/Renderer system should produce #{tag}")
    end

    # Verify AST structure is correct
    assert_not_nil(ast_root, 'Should have AST root')
    assert_equal(ReVIEW::AST::DocumentNode, ast_root.class)

    # Check that we have various node types
    headline_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(1, headline_nodes.size, 'Should have one headline')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 3, 'Should have multiple paragraphs')

    list_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal(2, list_nodes.size, 'Should have unordered and ordered lists')

    code_block_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_equal(1, code_block_nodes.size, 'Should have one code block')

    table_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::TableNode) }
    assert_equal(1, table_nodes.size, 'Should have one table')
  end
end
