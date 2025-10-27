# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/compiler/olnum_processor'
require 'review/book'
require 'review/book/chapter'

class TestOlnumProcessor < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)

    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test_chapter', 'test_chapter.re', StringIO.new)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_olnum_with_ordered_list
    source = <<~EOS
      = Chapter Title

      //olnum[5]

       1. First item (should start at 5)
       2. Second item (should be 6)
       3. Third item (should be 7)
    EOS

    @chapter.content = source

    # Build AST
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find the ordered list
    ordered_lists = find_list_nodes(ast_root, :ol)

    # List should have start_number set
    assert_equal 1, ordered_lists.length
    assert_equal 5, ordered_lists[0].start_number
  end

  def test_olnum_without_following_list
    source = <<~EOS
      = Chapter Title

      //olnum[3]

      This is a regular paragraph.
    EOS

    @chapter.content = source

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Check that no olnum block nodes remain
    olnum_blocks = find_block_nodes(ast_root, 'olnum')
    assert_equal 0, olnum_blocks.length

    # Check that no ordered lists exist
    ordered_lists = find_list_nodes(ast_root, :ol)
    assert_equal 0, ordered_lists.length
  end

  def test_multiple_olnum_commands
    source = <<~EOS
      = Chapter Title

      //olnum[10]

       1. First list item (should start at 10)
       2. Second list item (should be 11)

      Regular paragraph.

      //olnum[20]

       1. Another list (should start at 20)
       2. Another item (should be 21)
    EOS

    @chapter.content = source

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find the ordered lists
    ordered_lists = find_list_nodes(ast_root, :ol)

    # Both lists should have start_number set
    assert_equal 2, ordered_lists.length
    assert_equal 10, ordered_lists[0].start_number
    assert_equal 20, ordered_lists[1].start_number
  end

  private

  def find_list_nodes(node, list_type)
    result = []
    if node.is_a?(ReVIEW::AST::ListNode) && node.list_type == list_type
      result << node
    end

    if node.children
      node.children.each do |child|
        result.concat(find_list_nodes(child, list_type))
      end
    end

    result
  end

  def find_block_nodes(node, block_type)
    result = []
    if node.is_a?(ReVIEW::AST::BlockNode) && node.block_type.to_s == block_type
      result << node
    end

    node.children.each do |child|
      result.concat(find_block_nodes(child, block_type))
    end

    result
  end
end
