# frozen_string_literal: true

require_relative '../test_helper'
require 'stringio'
require 'ostruct'
require 'review/ast/compiler'
require 'review/book'
require 'review/configure'
require 'review/renderer/latex_renderer'
require 'review/renderer/list_structure_normalizer'

class ListStructureNormalizerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @config = ReVIEW::Configure.values
    @book = Book::Base.new
    @book.config = @config
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    @compiler = ReVIEW::AST::Compiler.for_chapter(@chapter)
    renderer = ReVIEW::Renderer::LatexRenderer.new(@chapter)
    @normalizer = ReVIEW::Renderer::ListStructureNormalizer.new(renderer)
  end

  def compile_ast(src)
    @chapter.content = src
    @compiler.compile_to_ast(@chapter)
  end

  def test_beginchild_nested_lists
    src = <<REVIEW
 * UL1

//beginchild

 1. UL1-OL1
 2. UL1-OL2

 * UL1-UL1
 * UL1-UL2

 : UL1-DL1
	UL1-DD1
 : UL1-DL2
	UL1-DD2

//endchild

 * UL2

//beginchild

UL2-PARA

//endchild
REVIEW

    ast = compile_ast(src)
    @normalizer.normalize(ast)

    document = ast.children.first
    assert_instance_of(ReVIEW::AST::ListNode, document)
    assert_equal :ul, document.list_type

    first_item = document.children.first
    assert_equal 'UL1', first_item.children.first.content

    nested_lists = first_item.children.select { |child| child.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 3, nested_lists.size

    ordered = nested_lists.find { |child| child.list_type == :ol }
    assert_not_nil(ordered)
    assert_equal(%w[UL1-OL1 UL1-OL2], ordered.children.map { |item| item.children.first.content })

    unordered = nested_lists.find { |child| child.list_type == :ul }
    assert_not_nil(unordered)
    assert_equal(%w[UL1-UL1 UL1-UL2], unordered.children.map { |item| item.children.first.content })

    definition = nested_lists.find { |child| child.list_type == :dl }
    assert_not_nil(definition)
    assert_equal(%w[UL1-DL1 UL1-DL2], definition.children.map { |item| item.term_children.first.content })
    assert_equal(%w[UL1-DD1 UL1-DD2], definition.children.map { |item| item.children.first.content.strip })

    second_item = document.children.last
    assert_equal 'UL2', second_item.children.first.content
    paragraph = second_item.children.last
    assert_instance_of(ReVIEW::AST::ParagraphNode, paragraph)
    assert_equal 'UL2-PARA', paragraph.children.first.content

    ordered.children.each_with_index do |item, index|
      assert_equal index + 1, item.instance_variable_get(:@idgxml_ol_offset)
    end
  end

  def test_definition_list_paragraphs_split
    src = <<REVIEW
: Term1
	First definition

: Term2
	Second line
	Third line
REVIEW

    ast = compile_ast(src)
    @normalizer.normalize(ast)

    definition = ast.children.first
    assert_instance_of(ReVIEW::AST::ListNode, definition)
    assert_equal :dl, definition.list_type

    items = definition.children
    assert_equal 2, items.size

    term1 = items.first
    assert_equal 'Term1', term1.term_children.first.content
    assert_equal 'First definition', term1.children.first.content.strip

    term2 = items.last
    assert_equal 'Term2', term2.term_children.first.content
    assert_equal(['Second line', 'Third line'], term2.children.map { |child| child.content.strip })
  end

  def test_missing_endchild_raises
    src = <<~REVIEW
      * UL1

      //beginchild

      * UL1-UL1
    REVIEW

    ast = compile_ast(src)
    assert_raise(ReVIEW::ApplicationError) { @normalizer.normalize(ast) }
  end
end
