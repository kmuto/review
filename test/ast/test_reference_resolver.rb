# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/reference_resolver'
require 'review/ast/reference_node'
require 'review/ast/inline_node'
require 'review/ast/document_node'
require 'review/ast/paragraph_node'
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

    # Setup table index
    table_index = ReVIEW::Book::Index.new
    table_index.add_item(ReVIEW::Book::Index::Item.new('tbl01', 1))

    # Setup list index
    list_index = ReVIEW::Book::Index.new
    list_index.add_item(ReVIEW::Book::Index::Item.new('list01', 1))

    # Setup footnote index
    footnote_index = ReVIEW::Book::Index.new
    footnote_index.add_item(ReVIEW::Book::Index::Item.new('fn01', 1))

    # Setup equation index
    equation_index = ReVIEW::Book::Index.new
    equation_index.add_item(ReVIEW::Book::Index::Item.new('eq01', 1))

    @chapter.ast_indexes = {
      image_index: image_index,
      table_index: table_index,
      list_index: list_index,
      footnote_index: footnote_index,
      equation_index: equation_index
    }

    @resolver = ReVIEW::AST::ReferenceResolver.new(@chapter)
  end

  def test_resolve_image_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ImageNode to generate index
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node)

    # Add inline reference to the image
    inline = ReVIEW::AST::InlineNode.new(inline_type: :img)
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
    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01')
    doc.add_child(table_node)

    # Add inline reference to the table
    inline = ReVIEW::AST::InlineNode.new(inline_type: :table)
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
    code_node = ReVIEW::AST::CodeBlockNode.new(id: 'list01', code_type: :list)
    doc.add_child(code_node)

    # Add inline reference to the list
    inline = ReVIEW::AST::InlineNode.new(inline_type: :list)
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
    inline = ReVIEW::AST::InlineNode.new(inline_type: :fn)
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
    eq_node = ReVIEW::AST::TexEquationNode.new(location: nil, id: 'eq01', latex_content: 'E=mc^2')
    doc.add_child(eq_node)

    # Add inline reference to the equation
    inline = ReVIEW::AST::InlineNode.new(inline_type: :eq)
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
    inline = ReVIEW::AST::InlineNode.new(inline_type: :w)
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
    inline = ReVIEW::AST::InlineNode.new(inline_type: :img)
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
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node)

    # Add labelref reference that should find the image
    inline = ReVIEW::AST::InlineNode.new(inline_type: :labelref)
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
    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01')
    doc.add_child(table_node)

    # Add ref reference that should find the table
    inline = ReVIEW::AST::InlineNode.new(inline_type: :ref)
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
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node)

    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01')
    doc.add_child(table_node)

    code_node = ReVIEW::AST::CodeBlockNode.new(id: 'list01', code_type: :list)
    doc.add_child(code_node)

    # Add multiple references
    inline1 = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref1 = ReVIEW::AST::ReferenceNode.new('img01')
    inline1.add_child(ref1)
    doc.add_child(inline1)

    inline2 = ReVIEW::AST::InlineNode.new(inline_type: :table)
    ref2 = ReVIEW::AST::ReferenceNode.new('tbl01')
    inline2.add_child(ref2)
    doc.add_child(inline2)

    inline3 = ReVIEW::AST::InlineNode.new(inline_type: :list)
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

  def test_resolve_endnote_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual FootnoteNode with endnote type
    en_node = ReVIEW::AST::FootnoteNode.new(location: nil, id: 'en01', footnote_type: :endnote)
    en_node.add_child(ReVIEW::AST::TextNode.new(content: 'Endnote content'))
    doc.add_child(en_node)

    # Add inline reference to the endnote
    inline = ReVIEW::AST::InlineNode.new(inline_type: :endnote)
    ref_node = ReVIEW::AST::ReferenceNode.new('en01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Endnote, data.class
    assert_equal 'en01', data.item_id
  end

  def test_resolve_column_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ColumnNode
    col_node = ReVIEW::AST::ColumnNode.new(location: nil, level: 3, label: 'col01')
    doc.add_child(col_node)

    # Add inline reference to the column
    inline = ReVIEW::AST::InlineNode.new(inline_type: :column)
    ref_node = ReVIEW::AST::ReferenceNode.new('col01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Column, data.class
    assert_equal 'col01', data.item_id
  end

  def test_resolve_headline_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual HeadlineNode
    headline = ReVIEW::AST::HeadlineNode.new(location: nil, level: 2, label: 'sec01')
    doc.add_child(headline)

    # Add inline reference to the headline
    inline = ReVIEW::AST::InlineNode.new(inline_type: :hd)
    ref_node = ReVIEW::AST::ReferenceNode.new('sec01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Headline, data.class
    assert_equal 'sec01', data.item_id
  end

  def test_resolve_section_reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual HeadlineNode
    headline = ReVIEW::AST::HeadlineNode.new(location: nil, level: 2, label: 'sec01')
    doc.add_child(headline)

    # Add inline reference using sec (alias for hd)
    inline = ReVIEW::AST::InlineNode.new(inline_type: :sec)
    ref_node = ReVIEW::AST::ReferenceNode.new('sec01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Headline, data.class
    assert_equal 'sec01', data.item_id
  end

  def test_resolve_chapter_reference
    # Setup chapter in book
    @book.instance_variable_set(:@chapter_index, ReVIEW::Book::ChapterIndex.new)
    chap_item = ReVIEW::Book::Index::Item.new('chap01', 1, @chapter)
    @book.chapter_index.add_item(chap_item)

    doc = ReVIEW::AST::DocumentNode.new

    # Add inline reference to the chapter
    inline = ReVIEW::AST::InlineNode.new(inline_type: :chap)
    ref_node = ReVIEW::AST::ReferenceNode.new('chap01')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Chapter, data.class
    assert_equal 'chap01', data.chapter_id
  end

  def test_resolve_cross_chapter_image_reference
    # Setup second chapter with proper ID
    chapter2 = ReVIEW::Book::Chapter.new(@book, 2, 'chap02', 'chap02.re')
    chapter2.instance_variable_set(:@number, '2')

    # Create AST with image node for chapter2
    doc2 = ReVIEW::AST::DocumentNode.new
    img_node2 = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc2.add_child(img_node2)

    # Build index for chapter2 using AST
    resolver2 = ReVIEW::AST::ReferenceResolver.new(chapter2)
    # Build indexes to populate chapter2's image_index
    resolver2.send(:build_indexes_from_ast, doc2)

    # Override @book.contents to return our test chapters
    # This is necessary because the actual contents method calculates from parts/chapters
    def @book.contents
      [@chapter, @chapter2].compact
    end
    @book.instance_variable_set(:@chapter, @chapter)
    @book.instance_variable_set(:@chapter2, chapter2)

    # Create main document with cross-chapter reference
    doc = ReVIEW::AST::DocumentNode.new

    # Add cross-chapter reference (chap02|img01)
    inline = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref_node = ReVIEW::AST::ReferenceNode.new('img01', 'chap02')
    inline.add_child(ref_node)
    doc.add_child(inline)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Image, data.class
    assert_equal '2', data.chapter_number
    assert_equal 'chap02', data.chapter_id
    assert_equal 'img01', data.item_id
  end

  def test_resolve_reference_in_paragraph
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ImageNode
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node)

    # Add paragraph containing inline reference
    para = ReVIEW::AST::ParagraphNode.new
    inline = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref_node = ReVIEW::AST::ReferenceNode.new('img01')
    inline.add_child(ref_node)
    para.add_child(inline)
    doc.add_child(para)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = para.children.first.children.first
    assert_true(resolved_node.resolved?)
  end

  def test_resolve_nested_inline_references
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ImageNode
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node)

    # Add paragraph with nested inline elements
    para = ReVIEW::AST::ParagraphNode.new

    # Bold inline containing image reference
    bold = ReVIEW::AST::InlineNode.new(inline_type: :b)
    img_inline = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref_node = ReVIEW::AST::ReferenceNode.new('img01')
    img_inline.add_child(ref_node)
    bold.add_child(img_inline)
    para.add_child(bold)
    doc.add_child(para)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    # Navigate to the resolved reference
    resolved_node = para.children.first.children.first.children.first
    assert_true(resolved_node.resolved?)
  end

  def test_resolve_reference_in_caption
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual FootnoteNode
    fn_node = ReVIEW::AST::FootnoteNode.new(location: nil, id: 'fn01')
    fn_node.add_child(ReVIEW::AST::TextNode.new(content: 'Footnote'))
    doc.add_child(fn_node)

    # Add table with caption containing footnote reference
    caption = ReVIEW::AST::CaptionNode.new
    inline = ReVIEW::AST::InlineNode.new(inline_type: :fn)
    ref_node = ReVIEW::AST::ReferenceNode.new('fn01')
    inline.add_child(ref_node)
    caption.add_child(inline)

    # Create table and set caption_node
    table_node = ReVIEW::AST::TableNode.new(id: 'tbl01', caption_node: caption)
    doc.add_child(table_node)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = caption.children.first.children.first
    assert_true(resolved_node.resolved?)
  end

  def test_resolve_multiple_references_same_inline
    doc = ReVIEW::AST::DocumentNode.new

    # Add actual ImageNodes
    img_node1 = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node1)
    img_node2 = ReVIEW::AST::ImageNode.new(id: 'img02', location: ReVIEW::SnapshotLocation.new(nil, 10))
    doc.add_child(img_node2)

    # Add single paragraph with multiple references
    para = ReVIEW::AST::ParagraphNode.new

    inline1 = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref1 = ReVIEW::AST::ReferenceNode.new('img01')
    inline1.add_child(ref1)
    para.add_child(inline1)

    para.add_child(ReVIEW::AST::TextNode.new(content: ' and '))

    inline2 = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref2 = ReVIEW::AST::ReferenceNode.new('img02')
    inline2.add_child(ref2)
    para.add_child(inline2)

    doc.add_child(para)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 2, failed: 0 }, result)

    # Both references should be resolved
    assert_true(para.children[0].children.first.resolved?)
    assert_true(para.children[2].children.first.resolved?)
  end

  def test_resolve_wb_reference
    # Setup dictionary in book config
    @book.config['dictionary'] = {
      'api' => 'Application Programming Interface'
    }

    doc = ReVIEW::AST::DocumentNode.new
    inline = ReVIEW::AST::InlineNode.new(inline_type: :wb)
    ref_node = ReVIEW::AST::ReferenceNode.new('api')

    doc.add_child(inline)
    inline.add_child(ref_node)

    result = @resolver.resolve_references(doc)

    assert_equal({ resolved: 1, failed: 0 }, result)

    resolved_node = inline.children.first
    assert_true(resolved_node.resolved?)

    data = resolved_node.resolved_data
    assert_equal ReVIEW::AST::ResolvedData::Word, data.class
    assert_equal 'Application Programming Interface', data.word_content
  end

  def test_mixed_resolved_and_unresolved_references
    doc = ReVIEW::AST::DocumentNode.new

    # Add one actual ImageNode
    img_node = ReVIEW::AST::ImageNode.new(id: 'img01', location: ReVIEW::SnapshotLocation.new(nil, 0))
    doc.add_child(img_node)

    # Add valid reference
    inline1 = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref1 = ReVIEW::AST::ReferenceNode.new('img01')
    inline1.add_child(ref1)
    doc.add_child(inline1)

    # Add invalid reference
    inline2 = ReVIEW::AST::InlineNode.new(inline_type: :img)
    ref2 = ReVIEW::AST::ReferenceNode.new('nonexistent')
    inline2.add_child(ref2)
    doc.add_child(inline2)

    # Should raise error for the invalid reference
    assert_raise(ReVIEW::CompileError) do
      @resolver.resolve_references(doc)
    end
  end
end
