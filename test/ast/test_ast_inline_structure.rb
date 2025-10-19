# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestASTInlineStructure < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_inline_element_ast_structure
    content = <<~EOB
      = Test Chapter

      Simple inline: @<b>{bold} and @<code>{code}.

      Ruby annotation: @<ruby>{漢字,かんじ}.

      References: @<href>{http://example.com, Link Text}.

      Keywords: @<kw>{Term, Description}.

      Heading ref: @<hd>{section}.

      Cross-refs: @<chap>{intro}, @<sec>{overview}.

      Word files: @<w>{words} and @<wb>{words2}.

      Complex ref: @<img>{figure1} and @<table>{data1}.
    EOB

    # Use AST::Compiler directly
    ast_root = compile_to_ast(content)

    assert_not_nil(ast_root)
    assert_equal(ReVIEW::AST::DocumentNode, ast_root.class)

    # Get all paragraph nodes
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal(8, paragraph_nodes.size)

    # Test simple inline elements
    simple_para = paragraph_nodes[0]
    bold_node = find_inline_node(simple_para, 'b')
    code_node = find_inline_node(simple_para, 'code')
    assert_not_nil(bold_node)
    assert_not_nil(code_node)
    assert_equal(['bold'], bold_node.args)
    assert_equal(['code'], code_node.args)

    # Test ruby inline element
    ruby_para = paragraph_nodes[1]
    ruby_node = find_inline_node(ruby_para, 'ruby')
    assert_not_nil(ruby_node)
    assert_equal(['漢字', 'かんじ'], ruby_node.args)

    # Test href inline element
    href_para = paragraph_nodes[2]
    href_node = find_inline_node(href_para, 'href')
    assert_not_nil(href_node)
    assert_equal(['http://example.com', 'Link Text'], href_node.args)

    # Test kw inline element
    kw_para = paragraph_nodes[3]
    kw_node = find_inline_node(kw_para, 'kw')
    assert_not_nil(kw_node)
    assert_equal(['Term', 'Description'], kw_node.args)

    # Test hd inline element
    hd_para = paragraph_nodes[4]
    hd_node = find_inline_node(hd_para, 'hd')
    assert_not_nil(hd_node)
    assert_equal(['section'], hd_node.args)

    # Test cross-reference inline elements
    cross_para = paragraph_nodes[5]
    chap_node = find_inline_node(cross_para, 'chap')
    sec_node = find_inline_node(cross_para, 'sec')
    assert_not_nil(chap_node)
    assert_not_nil(sec_node)
    assert_equal(['intro'], chap_node.args)
    assert_equal(['overview'], sec_node.args)

    # Test word expansion inline elements
    word_para = paragraph_nodes[6]
    w_node = find_inline_node(word_para, 'w')
    wb_node = find_inline_node(word_para, 'wb')
    assert_not_nil(w_node)
    assert_not_nil(wb_node)
    assert_equal(['words'], w_node.args)
    assert_equal(['words2'], wb_node.args)

    # Test reference inline elements
    ref_para = paragraph_nodes[7]
    img_node = find_inline_node(ref_para, 'img')
    table_node = find_inline_node(ref_para, 'table')
    assert_not_nil(img_node)
    assert_not_nil(table_node)
    assert_equal(['figure1'], img_node.args)
    assert_equal(['data1'], table_node.args)
  end

  def test_pipe_separated_inline_elements
    content = <<~EOB
      = Test Chapter

      Heading with chapter: @<hd>{chapter1|Introduction}.

      Image with chapter: @<img>{chap1|figure1}.

      List with chapter: @<list>{chap2|sample1}.

      Equation with chapter: @<eq>{chap3|formula1}.

      Table with chapter: @<table>{chap4|data1}.
    EOB

    # Use IndexBuilder to avoid validation issues
    # Use AST::Compiler directly
    ast_root = compile_to_ast(content)
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    # Test hd with chapter|heading format
    hd_para = paragraph_nodes[0]
    hd_node = find_inline_node(hd_para, 'hd')
    assert_not_nil(hd_node)
    assert_equal(['chapter1', 'Introduction'], hd_node.args)

    # Test img with chapter|id format
    img_para = paragraph_nodes[1]
    img_node = find_inline_node(img_para, 'img')
    assert_not_nil(img_node)
    assert_equal(['chap1', 'figure1'], img_node.args)

    # Test list with chapter|id format
    list_para = paragraph_nodes[2]
    list_node = find_inline_node(list_para, 'list')
    assert_not_nil(list_node)
    assert_equal(['chap2', 'sample1'], list_node.args)

    # Test eq with chapter|id format
    eq_para = paragraph_nodes[3]
    eq_node = find_inline_node(eq_para, 'eq')
    assert_not_nil(eq_node)
    assert_equal(['chap3', 'formula1'], eq_node.args)

    # Test table with chapter|id format
    table_para = paragraph_nodes[4]
    table_node = find_inline_node(table_para, 'table')
    assert_not_nil(table_node)
    assert_equal(['chap4', 'data1'], table_node.args)
  end

  def test_newly_added_inline_commands
    content = <<~EOB
      = Test Chapter

      Label references: @<labelref>{label1} and @<ref>{label2}.
    EOB

    # Use IndexBuilder to avoid validation issues
    # Use AST::Compiler directly
    ast_root = compile_to_ast(content)
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    # Test newly added label reference commands
    label_para = paragraph_nodes[0]
    labelref_node = find_inline_node(label_para, 'labelref')
    ref_node = find_inline_node(label_para, 'ref')
    assert_not_nil(labelref_node)
    assert_not_nil(ref_node)
    assert_equal(['label1'], labelref_node.args)
    assert_equal(['label2'], ref_node.args)
  end

  private

  def find_inline_node(paragraph, inline_type)
    paragraph.children.find do |child|
      child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == inline_type
    end
  end

  # Helper method to compile content to AST using AST::Compiler
  def compile_to_ast(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    # Use AST::Compiler directly
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_compiler.compile_to_ast(chapter, reference_resolution: false)
  end
end
