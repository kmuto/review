# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/reference_resolver'
require 'review/ast/reference_node'
require 'review/ast/inline_node'
require 'review/ast/document_node'
require 'review/book'
require 'review/book/chapter'

class ReferenceResolverTest < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'chap01', 'chap01.re')
    @chapter.instance_variable_set(:@number, '1')
    @chapter.instance_variable_set(:@title, 'Chapter 1')

    # Setup image index
    image_index = ReVIEW::Book::Index.new
    image_index.add_item(ReVIEW::Book::Index::Item.new('img01', 1))
    image_index.add_item(ReVIEW::Book::Index::Item.new('img02', 2))
    @chapter.instance_variable_set(:@image_index, image_index)

    # Setup table index
    table_index = ReVIEW::Book::Index.new
    table_index.add_item(ReVIEW::Book::Index::Item.new('tbl01', 1))
    @chapter.instance_variable_set(:@table_index, table_index)

    # Setup list index
    list_index = ReVIEW::Book::Index.new
    list_index.add_item(ReVIEW::Book::Index::Item.new('list01', 1))
    @chapter.instance_variable_set(:@list_index, list_index)

    # Setup footnote index
    footnote_index = ReVIEW::Book::Index.new
    footnote_index.add_item(ReVIEW::Book::Index::Item.new('fn01', 1))
    @chapter.instance_variable_set(:@footnote_index, footnote_index)

    # Setup equation index
    equation_index = ReVIEW::Book::Index.new
    equation_index.add_item(ReVIEW::Book::Index::Item.new('eq01', 1))
    @chapter.instance_variable_set(:@equation_index, equation_index)

    @resolver = ReVIEW::AST::ReferenceResolver.new(@chapter)
  end

  def test_resolve_image_reference
    # Create AST with actual image node and reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ImageNode to generate index
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', caption: nil)
    doc.add_child(img_node)

    # Add inline reference to the image
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'img')
    ref_node = ReVIEW::AST::ReferenceNode.new('img01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    # Resolve references
    result = @resolver.resolve_references(doc)

    # Check that reference was resolved
    assert_equal({ resolved: 1, failed: 0 }, result)

    # Check resolved data
    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)
    assert_not_nil(resolved_node.resolved_data)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Image, data.class
    assert_equal '1', data.chapter_number
    assert_equal '1', data.item_number
    assert_equal 'img01', data.item_id
  end

  def test_resolve_table_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual TableNode to generate index
    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01', caption: nil)
    doc.add_child(table_node)

    # Add inline reference to the table
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'table')
    ref_node = ReVIEW::AST::ReferenceNode.new('tbl01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Table, data.class
    assert_equal '1', data.chapter_number
    assert_equal '1', data.item_number
    assert_equal 'tbl01', data.item_id
  end

  def test_resolve_list_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual CodeBlockNode (list) to generate index
    code_node = ReVIEW::AST::CodeBlockNode.new(id: 'list01', code_type: :list, caption: nil)
    doc.add_child(code_node)

    # Add inline reference to the list
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'list')
    ref_node = ReVIEW::AST::ReferenceNode.new('list01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::List, data.class
    assert_equal '1', data.chapter_number
    assert_equal '1', data.item_number
    assert_equal 'list01', data.item_id
  end

  def test_resolve_footnote_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual FootnoteNode to generate index
    fn_node = ReVIEW::AST::FootnoteNode.new(location: nil, id: 'fn01')
    fn_node.add_child(ReVIEW::AST::TextNode.new(content: 'Footnote content'))
    doc.add_child(fn_node)

    # Add inline reference to the footnote
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'fn')
    ref_node = ReVIEW::AST::ReferenceNode.new('fn01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Footnote, data.class
    assert_equal 1, data.item_number
    assert_equal 'fn01', data.item_id
  end

  def test_resolve_equation_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual TexEquationNode to generate index
    eq_node = ReVIEW::AST::TexEquationNode.new(location: nil, id: 'eq01', caption: nil, latex_content: 'E=mc^2')
    doc.add_child(eq_node)

    # Add inline reference to the equation
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'eq')
    ref_node = ReVIEW::AST::ReferenceNode.new('eq01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Equation, data.class
    assert_equal '1', data.chapter_number
    assert_equal '1', data.item_number
    assert_equal 'eq01', data.item_id
  end

  def test_resolve_word_reference
    # Setup dictionary in book config
    @book.config['dictionary'] = {
      'rails' => 'Ruby on Rails',
      'ruby' => 'Ruby Programming Language'
    }

    doc = ReVIEW::AST::DocumentNode.new
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'w')
    ref_node = ReVIEW::AST::ReferenceNode.new('rails')

    doc.add_child(inline)
    inline.add_child(ref_node)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Word, data.class
    assert_equal 'Ruby on Rails', data.word_content
    assert_equal 'rails', data.item_id
  end

  def test_resolve_nonexistent_reference
    doc = ReVIEW::AST::DocumentNode.new
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'img')
    ref_node = ReVIEW::AST::ReferenceNode.new('nonexistent')

    doc.add_child(inline)
    inline.add_child(ref_node)

    # Should raise an error for non-existent reference
    assert_raise(ReVIEW::CompileError) do
      @resolver.resolve_references(doc)
    end
  end

  def test_resolve_label_reference_finds_image
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ImageNode to generate index
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', caption: nil)
    doc.add_child(img_node)

    # Add labelref reference that should find the image
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'labelref')
    ref_node = ReVIEW::AST::ReferenceNode.new('img01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Image, data.class
    assert_equal '1', data.chapter_number
    assert_equal '1', data.item_number
  end

  def test_resolve_label_reference_finds_table
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual TableNode to generate index
    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01', caption: nil)
    doc.add_child(table_node)

    # Add ref reference that should find the table
    inline = ReVIEW::AST::InlineNode.new(inline_type: 'ref')
    ref_node = ReVIEW::AST::ReferenceNode.new('tbl01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Table, data.class
    assert_equal '1', data.chapter_number
    assert_equal '1', data.item_number
  end

  def test_multiple_references
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual block nodes to generate indexes
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', caption: nil)
    doc.add_child(img_node)

    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01', caption: nil)
    doc.add_child(table_node)

    code_node = ReVIEW::AST::CodeBlockNode.new(id: 'list01', code_type: :list, caption: nil)
    doc.add_child(code_node)

    # Add multiple references
    inline1 = ReVIEW::AST::InlineNode.new(inline_type: 'img')
    ref1 = ReVIEW::AST::ReferenceNode.new('img01')
    inline1.add_child(ref1)
    doc.add_child(inline1)

    inline2 = ReVIEW::AST::InlineNode.new(inline_type: 'table')
    ref2 = ReVIEW::AST::ReferenceNode.new('tbl01')
    inline2.add_child(ref2)
    doc.add_child(inline2)

    inline3 = ReVIEW::AST::InlineNode.new(inline_type: 'list')
    ref3 = ReVIEW::AST::ReferenceNode.new('list01')
    inline3.add_child(ref3)
    doc.add_child(inline3)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 3, failed: 0 }, result)

    # Check all references are resolved
    assert_true(inline1.children.first.resolved?)
    assert_true(inline2.children.first.resolved?)
    assert_true(inline3.children.first.resolved?)
  end
end
