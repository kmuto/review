# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/review_generator'
require 'review/book'
require 'review/book/chapter'

class TestNewBlockCommands < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @book.config = @config
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test_chapter', 'test_chapter.re', StringIO.new)
  end

  def test_doorquote_block
    source = <<~EOS
      = Chapter Title

      //doorquote[author]{
      This is a door quote with some text.
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find doorquote node
    doorquote_node = find_node_by_type(ast_root, :doorquote)
    assert_not_nil(doorquote_node)
    assert_equal(:doorquote, doorquote_node.block_type)
    assert_equal(['author'], doorquote_node.args)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//doorquote[author]{')
    assert_include(result, 'This is a door quote with some text.')
    assert_include(result, '//}')
  end

  def test_bibpaper_block
    source = <<~EOS
      = Chapter Title

      //bibpaper[ref1][Title of Paper]{
      This paper discusses important topics.
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find bibpaper node
    bibpaper_node = find_node_by_type(ast_root, :bibpaper)
    assert_not_nil(bibpaper_node)
    assert_equal(:bibpaper, bibpaper_node.block_type)
    assert_equal(['ref1', 'Title of Paper'], bibpaper_node.args)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//bibpaper[ref1][Title of Paper]{')
    assert_include(result, 'This paper discusses important topics.')
    assert_include(result, '//}')
  end

  def test_talk_block
    source = <<~EOS
      = Chapter Title

      //talk{
      Speaker A: Hello there!
      Speaker B: Hi, how are you?
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find talk node
    talk_node = find_node_by_type(ast_root, :talk)
    assert_not_nil(talk_node)
    assert_equal(:talk, talk_node.block_type)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//talk{')
    assert_include(result, 'Speaker A: Hello there!')
    assert_include(result, 'Speaker B: Hi, how are you?')
    assert_include(result, '//}')
  end

  def test_graph_block
    source = <<~EOS
      = Chapter Title

      //graph[graph1][Graph Caption]{
      digraph G {
        A -> B;
        B -> C;
      }
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find graph node
    graph_node = find_node_by_type(ast_root, :graph)
    assert_not_nil(graph_node)
    assert_equal(:graph, graph_node.block_type)
    assert_equal(['graph1', 'Graph Caption'], graph_node.args)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//graph[graph1][Graph Caption]{')
    assert_include(result, 'digraph G {')
    assert_include(result, 'A -> B;')
  end

  def test_address_block
    source = <<~EOS
      = Chapter Title

      //address{
      123 Main Street
      City, State 12345
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find address node
    address_node = find_node_by_type(ast_root, :address)
    assert_not_nil(address_node)
    assert_equal(:address, address_node.block_type)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//address{')
    assert_include(result, '123 Main Street')
    assert_include(result, 'City, State 12345')
  end

  def test_box_block
    source = <<~EOS
      = Chapter Title

      //box[Box Title]{
      This is content inside a box.
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find box node
    box_node = find_node_by_type(ast_root, :box)
    assert_not_nil(box_node)
    assert_equal(:box, box_node.block_type)
    assert_equal(['Box Title'], box_node.args)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//box[Box Title]{')
    assert_include(result, 'This is content inside a box.')
  end

  def test_line_commands
    source = <<~EOS
      = Chapter Title

      //hr

      Some text here.

      //bpo

      More text.

      //parasep
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find line command nodes
    hr_node = find_node_by_type(ast_root, :hr)
    bpo_node = find_node_by_type(ast_root, :bpo)
    parasep_node = find_node_by_type(ast_root, :parasep)

    assert_not_nil(hr_node)
    assert_equal(:hr, hr_node.block_type)

    assert_not_nil(bpo_node)
    assert_equal(:bpo, bpo_node.block_type)

    assert_not_nil(parasep_node)
    assert_equal(:parasep, parasep_node.block_type)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, '//hr')
    assert_include(result, '//bpo')
    assert_include(result, '//parasep')
  end

  def test_blockquote_vs_quote
    source = <<~EOS
      = Chapter Title

      //quote{
      This is a regular quote.
      //}

      //blockquote{
      This is a block quote.
      //}
    EOS

    @chapter.content = source
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Both should be processed (quote was already implemented, blockquote is new)
    nodes = find_all_nodes_by_type(ast_root, %i[quote blockquote])
    assert_equal(2, nodes.length)

    quote_node = nodes.find { |n| n.block_type == :quote }
    blockquote_node = nodes.find { |n| n.block_type == :blockquote }

    assert_not_nil(quote_node)
    assert_not_nil(blockquote_node)

    # Test round-trip conversion
    generator = ReVIEW::AST::ReVIEWGenerator.new
    result = generator.generate(ast_root)
    assert_include(result, 'This is a regular quote.')
    assert_include(result, 'This is a block quote.')
  end

  private

  def find_node_by_type(node, block_type)
    return node if node.respond_to?(:block_type) && node.block_type == block_type

    if node.children
      node.children.each do |child|
        result = find_node_by_type(child, block_type)
        return result if result
      end
    end

    nil
  end

  def find_all_nodes_by_type(node, block_types)
    results = []
    block_types = [block_types] unless block_types.is_a?(Array)

    if node.respond_to?(:block_type) && block_types.include?(node.block_type)
      results << node
    end

    if node.children
      node.children.each do |child|
        results.concat(find_all_nodes_by_type(child, block_types))
      end
    end

    results
  end
end
