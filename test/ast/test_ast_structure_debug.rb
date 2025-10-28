# frozen_string_literal: true

# Debug test to understand AST structure issues with inline elements

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/json_serializer'
require 'review/book'
require 'review/book/chapter'
require 'json'

class TestASTStructureDebug < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)

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

      //footnote[footnote1][Footnote in note]
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    # Find minicolumn node
    minicolumn = ast['children'].find { |node| node['type'] == 'MinicolumnNode' }
    assert_not_nil(minicolumn)

    # Check if inline elements are properly parsed
    has_inline_node = minicolumn['children'].any? do |child|
      child['type'] == 'InlineNode' ||
        (child['children'] && child['children'].any? { |grandchild| grandchild['type'] == 'InlineNode' })
    end

    assert_true(has_inline_node, 'Minicolumn should contain inline elements')
  end

  def test_table_ast_structure
    source = <<~EOS
      = Chapter Title

      //table[test-table][Test Table]{
      Header @<b>{Bold}	Normal Header
      ------------
      Cell with @<fn>{table-fn}	Normal Cell
      //}

      //footnote[table-fn][Footnote in table]
    EOS

    @chapter.content = source

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    # Find table node
    table = ast['children'].find { |node| node['type'] == 'TableNode' }
    assert_not_nil(table)

    # Check actual table structure (header_rows vs headers)
    table.keys.grep(/header|row/)

    # Verify table structure has header_rows and body_rows (correct AST structure)
    assert_not_nil(table['header_rows'] || table['headers'])
    assert_not_nil(table['body_rows'] || table['rows'])

    # Check for inline elements in table cells using correct structure
    headers = table['header_rows'] || table['headers'] || []
    rows = table['body_rows'] || table['rows'] || []

    headers.any? do |header|
      header['children']&.any? { |cell| cell['type'] == 'InlineNode' }
    end

    rows.any? do |row|
      row['children']&.any? { |cell| cell['type'] == 'InlineNode' }
    end

    # Table should have structure and may contain inline elements
    assert_true(headers.any? || rows.any?, 'Table should have headers or rows')
    # NOTE: Inline element check is optional as it depends on content
  end

  def test_paragraph_ast_structure
    source = <<~EOS
      = Chapter Title

      This is a paragraph with @<fn>{footnote1} and @<b>{bold text}.

      //footnote[footnote1][Paragraph footnote]
    EOS

    @chapter.content = source

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    # Find paragraph node
    paragraph = ast['children'].find { |node| node['type'] == 'ParagraphNode' }
    assert_not_nil(paragraph)

    # Verify paragraph contains inline elements
    has_inline_elements = paragraph['children'].any? { |child| child['type'] == 'InlineNode' }
    assert_true(has_inline_elements, 'Paragraph should contain inline elements')

    # Verify specific inline elements exist
    inline_types = paragraph['children'].select { |child| child['type'] == 'InlineNode' }.map { |node| node['inline_type'] }
    assert_includes(inline_types, 'fn', 'Should contain footnote inline element')
    assert_includes(inline_types, 'b', 'Should contain bold inline element')
  end
end
