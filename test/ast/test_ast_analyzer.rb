#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../test_helper'
require 'review'
require 'review/ast'
require 'review/ast/analyzer'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/i18n'
require 'stringio'

class TestASTAnalyzer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_statistics
    ast_root = compile_content(<<~EOB)
      = Test Chapter
      
      This is a @<b>{bold} test.
      
      //emlist[Example]{
      puts 'hello'
      //}
    EOB

    stats = ReVIEW::AST::Analyzer.statistics(ast_root)

    assert stats.key?(:total_nodes), 'Statistics should include total_nodes'
    assert stats.key?(:node_types), 'Statistics should include node_types'
    assert stats.key?(:depth), 'Statistics should include depth'

    assert stats[:total_nodes] > 5, 'Should have multiple nodes'
    assert stats[:node_types]['DocumentNode'] == 1, 'Should have one DocumentNode'
    assert stats[:depth] > 2, 'Should have reasonable depth'
  end

  def test_node_types_count
    ast_root = compile_content(<<~EOB)
      = Chapter Title
      
      //emlist[Code Example]{
      puts 'hello'
      //}
      
      //note[Note Title]{
      This is a note.
      //}
    EOB

    node_types = ReVIEW::AST::Analyzer.collect_node_types(ast_root)

    assert node_types.include?('DocumentNode'), 'Should include DocumentNode'
    assert node_types.include?('HeadlineNode'), 'Should include HeadlineNode'
    assert node_types.include?('CodeBlockNode'), 'Should include CodeBlockNode'
    assert node_types.include?('MinicolumnNode'), 'Should include MinicolumnNode'
  end

  def test_depth_calculation
    ast_root = compile_content(<<~EOB)
      = Test
      
      Hello @<b>{world}!
    EOB

    depth = ReVIEW::AST::Analyzer.calculate_depth(ast_root)

    assert depth > 2, 'Should have reasonable depth for nested structure'
  end

  def test_node_counting
    ast_root = compile_content(<<~EOB)
      = Chapter
      
      Text with @<i>{italic} and @<b>{bold}.
    EOB

    count = ReVIEW::AST::Analyzer.count_nodes(ast_root)

    assert count > 5, 'Should count multiple nodes including inline elements'
  end

  private

  def compile_content(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    @book.generate_indexes
    chapter.generate_indexes

    # Use AST::Compiler directly
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_compiler.compile_to_ast(chapter)
  end
end
