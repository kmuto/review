# frozen_string_literal: true

# Debug test to understand AST structure issues with inline elements

require_relative 'test_helper'
require 'review/ast/compiler'
require 'review/ast/json_serializer'
require 'review/book'
require 'review/book/chapter'
require 'json'

class TestASTStructureDebug < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book.config = @config

    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'debug_chapter', 'debug_chapter.re', StringIO.new)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_minicolumn_ast_structure
    source = <<~EOS
      = Chapter Title

      //note[Note Caption]{
      This is a note with @<fn>{footnote1}.
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new(nil)
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    puts '=== Minicolumn AST Structure ==='
    puts JSON.pretty_generate(ast)

    # Find minicolumn node
    minicolumn = ast['children'].find { |node| node['type'] == 'MinicolumnNode' }
    assert_not_nil(minicolumn)

    puts "\n=== Minicolumn Children ==="
    puts JSON.pretty_generate(minicolumn['children'])

    # Check if inline elements are properly parsed
    has_inline_node = minicolumn['children'].any? do |child|
      child['type'] == 'InlineNode' ||
        (child['children'] && child['children'].any? { |grandchild| grandchild['type'] == 'InlineNode' })
    end

    puts "\nHas inline node: #{has_inline_node}"
  end

  def test_table_ast_structure
    source = <<~EOS
      = Chapter Title

      //table[test-table][Test Table]{
      Header @<b>{Bold}	Normal Header
      ------------
      Cell with @<fn>{table-fn}	Normal Cell
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new(nil)
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    puts "\n=== Table AST Structure ==="
    puts JSON.pretty_generate(ast)

    # Find table node
    table = ast['children'].find { |node| node['type'] == 'TableNode' }
    assert_not_nil(table)

    puts "\n=== Table Headers ==="
    puts JSON.pretty_generate(table['headers'])
    puts "\n=== Table Rows ==="
    puts JSON.pretty_generate(table['rows'])
  end

  def test_paragraph_ast_structure
    source = <<~EOS
      = Chapter Title

      This is a paragraph with @<fn>{footnote1} and @<b>{bold text}.
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new(nil)
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    puts "\n=== Paragraph AST Structure ==="
    puts JSON.pretty_generate(ast)

    # Find paragraph node
    paragraph = ast['children'].find { |node| node['type'] == 'ParagraphNode' }
    assert_not_nil(paragraph)

    puts "\n=== Paragraph Children ==="
    puts JSON.pretty_generate(paragraph['children'])
  end
end
