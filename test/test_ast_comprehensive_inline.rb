# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast'
require 'review/ast/renderer'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/index_builder'
require 'review/jsonbuilder'
require 'review/book'
require 'review/book/chapter'

class TestASTComprehensiveInline < Test::Unit::TestCase
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

  def test_advanced_inline_elements_ast_processing # rubocop:disable Metrics/CyclomaticComplexity
    content = <<~EOB
      = Advanced Inline Elements

      This paragraph tests @<hd>{Introduction} heading reference.

      Cross-references: @<img>{figure1} and @<list>{sample1}.

      Chapter references: @<chap>{chapter2} and @<chapref>{chapter3}.

      Section references: @<sec>{section1} and @<secref>{section2}.

      Label references: @<labelref>{label1} and @<ref>{label2}.

      Word expansion: @<w>{filename} and @<wb>{wordfile}.

      Math equation: @<eq>{equation}.

      Table reference: @<table>{table1}.
    EOB

    # Use JsonBuilder to get JSON output and verify AST structure
    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    json_result = compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Verify JSON output contains the expected content
    assert(json_result.include?('Introduction'), 'JSON should include hd content')
    assert(json_result.include?('figure1'), 'JSON should include img reference')
    assert(json_result.include?('sample1'), 'JSON should include list reference')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    # Test hd inline element
    hd_para = paragraph_nodes[0]
    hd_node = hd_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'hd' }
    assert_not_nil(hd_node)
    assert_equal ['Introduction'], hd_node.args

    # Test img and list inline elements
    ref_para = paragraph_nodes[1]
    img_node = ref_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'img' }
    list_node = ref_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'list' }
    assert_not_nil(img_node)
    assert_not_nil(list_node)
    assert_equal ['figure1'], img_node.args
    assert_equal ['sample1'], list_node.args

    # Test chapter cross-references
    chap_para = paragraph_nodes[2]
    chap_node = chap_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'chap' }
    chapref_node = chap_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'chapref' }
    assert_not_nil(chap_node)
    assert_not_nil(chapref_node)
    assert_equal ['chapter2'], chap_node.args
    assert_equal ['chapter3'], chapref_node.args

    # Test section cross-references
    sec_para = paragraph_nodes[3]
    sec_node = sec_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'sec' }
    secref_node = sec_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'secref' }
    assert_not_nil(sec_node)
    assert_not_nil(secref_node)
    assert_equal ['section1'], sec_node.args
    assert_equal ['section2'], secref_node.args

    # Test label references
    label_para = paragraph_nodes[4]
    labelref_node = label_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'labelref' }
    ref_node = label_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'ref' }
    assert_not_nil(labelref_node)
    assert_not_nil(ref_node)
    assert_equal ['label1'], labelref_node.args
    assert_equal ['label2'], ref_node.args

    # Test word expansion
    word_para = paragraph_nodes[5]
    w_node = word_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'w' }
    wb_node = word_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'wb' }
    assert_not_nil(w_node)
    assert_not_nil(wb_node)
    assert_equal ['filename'], w_node.args
    assert_equal ['wordfile'], wb_node.args

    # Test equation reference
    eq_para = paragraph_nodes[6]
    eq_node = eq_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'eq' }
    assert_not_nil(eq_node)
    assert_equal ['equation'], eq_node.args

    # Test table reference
    table_para = paragraph_nodes[7]
    table_node = table_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == 'table' }
    assert_not_nil(table_node)
    assert_equal ['table1'], table_node.args
  end

  def test_inline_elements_in_paragraphs_with_jsonbuilder
    content = <<~EOB
      = Inline Elements Test

      This paragraph has @<b>{bold} and @<i>{italic} formatting.

      Another paragraph with @<code>{code} and @<tt>{typewriter} text.

      Special elements: @<ruby>{漢字,かんじ} and @<href>{http://example.com, Link}.

      Keywords: @<kw>{HTTP, Protocol} and formatting.

      Final paragraph with normal text.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    json_result = compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Verify JSON output contains inline element content
    assert(json_result.include?('bold'), 'JSON should include bold content')
    assert(json_result.include?('italic'), 'JSON should include italic content')
    assert(json_result.include?('code'), 'JSON should include code content')
    assert(json_result.include?('typewriter'), 'JSON should include typewriter content')
    assert(json_result.include?('漢字'), 'JSON should include ruby content')
    assert(json_result.include?('example.com'), 'JSON should include href content')
    assert(json_result.include?('HTTP'), 'JSON should include kw content')

    # Check that paragraphs are processed via AST with inline elements
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 4, 'Should have multiple paragraphs processed via AST')

    # Check that inline elements are properly structured in AST
    inline_paragraphs = paragraph_nodes.select do |para|
      para.children.any?(ReVIEW::AST::InlineNode)
    end
    assert(inline_paragraphs.size >= 3, 'Should have paragraphs with inline elements')

    # Check for specific inline types
    all_inline_types = []
    inline_paragraphs.each do |para|
      para.children.each do |child|
        if child.is_a?(ReVIEW::AST::InlineNode)
          all_inline_types << child.inline_type
        end
      end
    end

    expected_types = %w[b i code tt ruby href kw]
    expected_types.each do |type|
      assert(all_inline_types.include?(type), "Should have inline type: #{type}")
    end
  end

  def test_json_output_structure_verification
    content = <<~EOB
      = JSON Structure Test

      This paragraph contains @<b>{bold} text and @<code>{code} elements.

      Another paragraph with @<href>{https://example.com, example link}.

      Final paragraph with normal text only.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    json_result = compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Verify JSON output structure and content
    assert(json_result.include?('DocumentNode'), 'JSON should contain DocumentNode type')
    assert(json_result.include?('HeadlineNode'), 'JSON should contain HeadlineNode type')
    assert(json_result.include?('ParagraphNode'), 'JSON should contain ParagraphNode type')
    assert(json_result.include?('JSON Structure Test'), 'JSON should include headline caption')
    assert(json_result.include?('bold'), 'JSON should include inline content')
    assert(json_result.include?('code'), 'JSON should include inline content')
    assert(json_result.include?('example.com'), 'JSON should include href content')

    # Verify AST structure
    assert_not_nil(ast_root, 'Should have AST root')
    assert_equal(ReVIEW::AST::DocumentNode, ast_root.class)

    headline_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(1, headline_nodes.size, 'Should have one headline')
    assert_equal('JSON Structure Test', headline_nodes.first.caption)

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal(3, paragraph_nodes.size, 'Should have three paragraphs')

    # Check inline elements in paragraphs
    inline_paragraphs = paragraph_nodes.select do |para|
      para.children.any?(ReVIEW::AST::InlineNode)
    end
    assert_equal(2, inline_paragraphs.size, 'Should have two paragraphs with inline elements')
  end

  def test_raw_content_processing_with_embed_blocks
    content = <<~EOB
      = Raw Content Test

      Before embed block.

      //embed[html]{
      <div class="custom">Raw HTML content</div>
      <script>console.log('test');</script>
      //}

      Middle paragraph with @<b>{bold} text.

      //embed[css]{
      .custom { color: red; }
      //}

      After embed blocks.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph embed])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    json_result = compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Verify JSON output contains raw/embed content information
    assert(json_result.include?('html'), 'JSON should include html embed arg')
    assert(json_result.include?('css'), 'JSON should include css embed arg')
    assert(json_result.include?('custom'), 'JSON should include raw HTML content')
    assert(json_result.include?('console.log'), 'JSON should include raw script content')
    assert(json_result.include?('color: red'), 'JSON should include raw CSS content')
    assert(json_result.include?('EmbedNode'), 'JSON should contain EmbedNode type')

    # Verify AST structure
    assert_not_nil(ast_root, 'Should have AST root')

    # Check embed nodes
    embed_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_equal(2, embed_nodes.size, 'Should have two embed nodes')

    # Check HTML embed
    html_embed = embed_nodes.find { |n| n.arg == 'html' }
    assert_not_nil(html_embed, 'Should have HTML embed node')
    assert_equal(:block, html_embed.embed_type, 'Should be block embed type')
    assert_equal(2, html_embed.lines.size, 'Should have two lines of HTML content')
    assert(html_embed.lines.any? { |line| line.include?('custom') }, 'Should contain custom class')
    assert(html_embed.lines.any? { |line| line.include?('console.log') }, 'Should contain script')

    # Check CSS embed
    css_embed = embed_nodes.find { |n| n.arg == 'css' }
    assert_not_nil(css_embed, 'Should have CSS embed node')
    assert_equal(1, css_embed.lines.size, 'Should have one line of CSS content')
    assert(css_embed.lines.first.include?('color: red'), 'Should contain CSS rule')

    # Check that regular paragraphs are also processed
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 3, 'Should have multiple paragraphs')

    # Check inline elements in middle paragraph
    middle_para = paragraph_nodes.find do |para|
      para.children.any? { |child| child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == 'b' }
    end
    assert_not_nil(middle_para, 'Should have paragraph with bold inline element')
  end

  def test_raw_single_command_processing
    content = <<~EOB
      = Raw Command Test

      Before raw command.

      //raw[|html|<div class="inline-raw">Inline raw content</div>]

      Middle paragraph with @<b>{bold} text.

      //raw[|latex|\\textbf{LaTeX raw content}]

      After raw commands.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: %i[headline paragraph])
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    json_result = compiler.compile(chapter)
    ast_root = compiler.ast_result

    # Raw commands are processed traditionally, so they won't appear in JSON structure
    # but the surrounding content should be properly processed
    assert(json_result.include?('Raw Command Test'), 'JSON should include headline')
    assert(json_result.include?('Before raw command'), 'JSON should include before paragraph')
    assert(json_result.include?('After raw commands'), 'JSON should include after paragraph')
    assert(json_result.include?('bold'), 'JSON should include inline content')

    # Verify AST structure (raw commands are not in AST, but paragraphs are)
    assert_not_nil(ast_root, 'Should have AST root')

    headline_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(1, headline_nodes.size, 'Should have one headline')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 3, 'Should have multiple paragraphs processed via AST')

    # Check that middle paragraph has inline elements
    middle_para = paragraph_nodes.find do |para|
      para.children.any? { |child| child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == 'b' }
    end
    assert_not_nil(middle_para, 'Should have paragraph with bold inline element')

    # Verify paragraph content
    before_para = paragraph_nodes.find do |para|
      para.children.any? { |child| child.is_a?(ReVIEW::AST::TextNode) && child.content.include?('Before raw command') }
    end
    assert_not_nil(before_para, 'Should have before paragraph in AST')

    after_para = paragraph_nodes.find do |para|
      para.children.any? { |child| child.is_a?(ReVIEW::AST::TextNode) && child.content.include?('After raw commands') }
    end
    assert_not_nil(after_para, 'Should have after paragraph in AST')
  end

  def test_comprehensive_inline_compatibility
    content = <<~EOB
      = Comprehensive Inline Test

      Text with @<b>{bold}, @<i>{italic}, @<code>{code}, and @<ruby>{漢字,かんじ}.

      Advanced: @<href>{http://example.com, Link} and @<kw>{Term, Description}.

      Words: @<w>{glossary} and @<wb>{abbreviations}.
    EOB

    # Test AST structure with JsonBuilder
    builder_ast = ReVIEW::JSONBuilder.new
    compiler_ast = ReVIEW::Compiler.new(builder_ast, ast_mode: true, ast_elements: %i[headline paragraph])
    chapter_ast = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_ast.content = content

    json_result_ast = compiler_ast.compile(chapter_ast)

    # Verify JSON contains expected inline element content
    assert(json_result_ast.include?('bold'), 'JSON should include bold content')
    assert(json_result_ast.include?('italic'), 'JSON should include italic content')
    assert(json_result_ast.include?('code'), 'JSON should include code content')
    assert(json_result_ast.include?('glossary'), 'JSON should include word expansion content')

    ast_root = compiler_ast.ast_result
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    # Verify AST structure includes all inline types
    inline_types = []
    paragraph_nodes.each do |para|
      para.children.each do |child|
        if child.is_a?(ReVIEW::AST::InlineNode)
          inline_types << child.inline_type
        end
      end
    end

    expected_types = %w[b i code ruby href kw w wb]
    expected_types.each do |type|
      assert(inline_types.include?(type), "Should have inline type: #{type}")
    end

    # Test traditional mode with simpler content to verify compatibility
    simple_content = <<~EOB
      = Simple Test

      Text with @<b>{bold} and @<i>{italic}.
    EOB

    builder_trad = ReVIEW::HTMLBuilder.new
    compiler_trad = ReVIEW::Compiler.new(builder_trad)
    chapter_trad = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_trad.content = simple_content
    result_trad = compiler_trad.compile(chapter_trad)

    # Should process basic inline elements
    ['<b>', '<i>'].each do |tag|
      assert(result_trad.include?(tag), "Traditional mode should produce #{tag}")
    end
  end
end
