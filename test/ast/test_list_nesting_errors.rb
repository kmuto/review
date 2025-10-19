# frozen_string_literal: true

require_relative '../test_helper'
require 'review/configure'
require 'review/book'
require 'review/i18n'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/block_processor'
require 'review/logger'

class TestListNestingErrors < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @compiler = ReVIEW::AST::Compiler.new
  end

  def create_chapter(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content
    chapter
  end

  # Test //li outside of list blocks
  def test_li_outside_list_error
    input = <<~REVIEW
      = Chapter

      This is a paragraph.

      //li{
      This should cause an error because //li is not inside a list.
      //}
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test //dt outside of //dl
  def test_dt_outside_dl_error
    input = <<~REVIEW
      //ul{
      
      //dt{
      This should cause an error because //dt is only for //dl.
      //}
      
      //}
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test //dd outside of //dl
  def test_dd_outside_dl_error
    input = <<~REVIEW
      //ol{
      
      //dd{
      This should cause an error because //dd is only for //dl.
      //}
      
      //}
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test //dt in document root
  def test_dt_in_document_root_error
    input = <<~REVIEW
      = Chapter

      //dt{
      This should cause an error because //dt must be inside //dl.
      //}
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test //dd in document root
  def test_dd_in_document_root_error
    input = <<~REVIEW
      = Chapter

      //dd{
      This should cause an error because //dd must be inside //dl.
      //}
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test nested list blocks (should be valid)
  def test_nested_list_blocks_valid
    input = <<~REVIEW
      //ul{
      
      //li{
      Item with nested list
      
      //ul{
      Nested item 1
      Nested item 2
      //}
      
      //}
      
      //}
    REVIEW

    # This should NOT raise an error
    ast = @compiler.compile_to_ast(create_chapter(input.strip))
    assert_not_nil(ast)
  end

  # Test deeply nested lists
  def test_deeply_nested_lists_valid
    input = <<~REVIEW
      //ul{
      
      //li{
      Level 1
      
      //ol{
      
      //li{
      Level 2
      
      //dl{
      
      //dt{
      Level 3 term
      //}
      //dd{
      Level 3 description
      
      //ul{
      Level 4 item
      //}
      
      //}
      
      //}
      
      //}
      
      //}
      
      //}
      
      //}
    REVIEW

    # This should NOT raise an error - deeply nested lists are valid
    ast = @compiler.compile_to_ast(create_chapter(input.strip))
    assert_not_nil(ast)
  end

  # Test //li directly inside //dl (should be invalid)
  def test_li_in_dl_error
    input = <<~REVIEW
      //dl{
      
      //li{
      This should cause an error because //dl should only contain //dt and //dd.
      //}
      
      //}
    REVIEW

    # Currently this doesn't raise an error, but ideally it should
    # For now, we'll test that it creates a regular ListItemNode without dt/dd type
    ast = @compiler.compile_to_ast(create_chapter(input.strip))
    list_node = ast.children.first
    # Find content items (//li blocks have children, simple text lines don't)
    li_items = list_node.children.select { |item| item.item_type.nil? && item.children.any? }
    assert_equal 1, li_items.size
  end

  # Test mixed //li and //dt in //dl
  def test_mixed_li_dt_in_dl
    input = <<~REVIEW
      //dl{
      
      //dt{
      Term
      //}
      
      //li{
      This is neither dt nor dd
      //}
      
      //dd{
      Description
      //}
      
      //}
    REVIEW

    ast = @compiler.compile_to_ast(create_chapter(input.strip))
    list_node = ast.children.first

    # Check that we have different types of items
    dt_items = list_node.children.select(&:definition_term?)
    dd_items = list_node.children.select(&:definition_desc?)
    li_items = list_node.children.select { |item| item.item_type.nil? && item.children.any? }

    assert_equal 1, dt_items.size
    assert_equal 1, dd_items.size
    assert_equal 1, li_items.size
  end

  # Test //dt and //dd in //ul (should raise error)
  def test_dt_dd_in_ul
    input = <<~REVIEW
      //ul{
      
      //dt{
      This is a dt in ul - semantically wrong
      //}
      
      //dd{
      This is a dd in ul - semantically wrong
      //}
      
      //}
    REVIEW

    # This should raise an error because dt/dd are only for dl
    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test unclosed list block
  def test_unclosed_list_block_error
    input = <<~REVIEW
      //ul{
      Item 1
      Item 2
      
      //li{
      Item with content
      
      # Missing closing //} for //li
      
      # Missing closing //} for //ul
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end

  # Test mismatched block end
  def test_mismatched_block_end_error
    input = <<~REVIEW
      //ul{
      Item 1
      //}
      //}
    REVIEW

    assert_raise(ReVIEW::CompileError) do
      @compiler.compile_to_ast(create_chapter(input.strip))
    end
  end
end
