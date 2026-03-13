# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/html_renderer'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestASTComprehensiveInline < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @config['dictionary'] = {
      'glossary' => 'glossary',
      'abbreviations' => 'abbreviations'
    }
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_advanced_inline_elements_ast_processing
    content = <<~EOB
      = Advanced Inline Elements

      This paragraph tests @<b>{bold} text and @<i>{italic} text.

      Basic formatting: @<code>{code} and @<tt>{typewriter}.

      Ruby text: @<ruby>{漢字,かんじ} and @<kw>{HTTP,Protocol}.

      Links: @<href>{http://example.com,example} text.

      Simple inline elements without references.
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = renderer.render(ast_root)

    assert(html_result.include?('bold'), 'HTML should include bold content')
    assert(html_result.include?('italic'), 'HTML should include italic content')
    assert(html_result.include?('code'), 'HTML should include code content')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    first_para = paragraph_nodes[0]
    b_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :b }
    i_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :i }
    assert_not_nil(b_node)
    assert_equal ['bold'], b_node.args
    assert_not_nil(i_node)
    assert_equal ['italic'], i_node.args

    second_para = paragraph_nodes[1]
    code_node = second_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :code }
    tt_node = second_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :tt }
    assert_not_nil(code_node)
    assert_not_nil(tt_node)
    assert_equal ['code'], code_node.args
    assert_equal ['typewriter'], tt_node.args

    third_para = paragraph_nodes[2]
    ruby_node = third_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :ruby }
    kw_node = third_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :kw }
    assert_not_nil(ruby_node)
    assert_not_nil(kw_node)
    assert_equal ['漢字', 'かんじ'], ruby_node.args
    assert_equal ['HTTP', 'Protocol'], kw_node.args

    fourth_para = paragraph_nodes[3]
    href_node = fourth_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :href }
    assert_not_nil(href_node)
    assert_equal ['http://example.com', 'example'], href_node.args
  end

  def test_inline_elements_in_paragraphs_with_ast_renderer
    content = <<~EOB
      = Inline Elements Test

      This paragraph has @<b>{bold} and @<i>{italic} formatting.

      Another paragraph with @<code>{code} and @<tt>{typewriter} text.

      Special elements: @<ruby>{漢字,かんじ} and @<href>{http://example.com, Link}.

      Keywords: @<kw>{HTTP, Protocol} and formatting.

      Final paragraph with normal text.
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = renderer.render(ast_root)

    assert(html_result.include?('bold'), 'HTML should include bold content')
    assert(html_result.include?('italic'), 'HTML should include italic content')
    assert(html_result.include?('code'), 'HTML should include code content')
    assert(html_result.include?('typewriter'), 'HTML should include typewriter content')
    assert(html_result.include?('漢字'), 'HTML should include ruby content')
    assert(html_result.include?('example.com'), 'HTML should include href content')
    assert(html_result.include?('HTTP'), 'HTML should include kw content')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 4, 'Should have multiple paragraphs processed via AST')

    inline_paragraphs = paragraph_nodes.select do |para|
      para.children.any?(ReVIEW::AST::InlineNode)
    end
    assert(inline_paragraphs.size >= 3, 'Should have paragraphs with inline elements')

    all_inline_types = []
    inline_paragraphs.each do |para|
      para.children.each do |child|
        if child.is_a?(ReVIEW::AST::InlineNode)
          all_inline_types << child.inline_type
        end
      end
    end

    expected_types = %i[b i code tt ruby href kw]
    expected_types.each do |type|
      assert(all_inline_types.include?(type), "Should have inline type: #{type}")
    end
  end

  def test_ast_output_structure_verification
    content = <<~EOB
      = AST Structure Test

      This paragraph contains @<b>{bold} text and @<code>{code} elements.

      Another paragraph with @<href>{https://example.com, example link}.

      Final paragraph with normal text only.
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = renderer.render(ast_root)

    assert(html_result.include?('<h1>'), 'HTML should contain h1 tag for headlines')
    assert(html_result.include?('<p>'), 'HTML should contain p tag for paragraphs')
    assert(html_result.include?('AST Structure Test'), 'HTML should include headline caption')
    assert(html_result.include?('bold'), 'HTML should include inline content')
    assert(html_result.include?('code'), 'HTML should include inline content')
    assert(html_result.include?('example.com'), 'HTML should include href content')

    assert_not_nil(ast_root, 'Should have AST root')
    assert_equal(ReVIEW::AST::DocumentNode, ast_root.class)

    headline_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(1, headline_nodes.size, 'Should have one headline')
    assert_equal('AST Structure Test', headline_nodes.first.caption_text)

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal(3, paragraph_nodes.size, 'Should have three paragraphs')

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

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = renderer.render(ast_root)

    assert(html_result.include?('Raw Content Test'), 'HTML should include headline')
    assert(html_result.include?('Before embed block'), 'HTML should include content before embed')
    assert(html_result.include?('After embed blocks'), 'HTML should include content after embed')
    assert(html_result.include?('bold'), 'HTML should include inline content')

    assert_not_nil(ast_root, 'Should have AST root')

    embed_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_equal(2, embed_nodes.size, 'Should have two embed nodes')

    html_embed = embed_nodes.find { |n| n.target_builders&.include?('html') }
    assert_not_nil(html_embed, 'Should have HTML embed node')
    assert_equal(:block, html_embed.embed_type, 'Should be block embed type')
    assert(html_embed.content.include?('custom'), 'Should contain custom class')
    assert(html_embed.content.include?('console.log'), 'Should contain script')

    css_embed = embed_nodes.find { |n| n.target_builders&.include?('css') }
    assert_not_nil(css_embed, 'Should have CSS embed node')
    assert(css_embed.content.include?('color: red'), 'Should contain CSS rule')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 3, 'Should have multiple paragraphs')

    middle_para = paragraph_nodes.find do |para|
      para.children.any? { |child| child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == :b }
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

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = renderer.render(ast_root)

    assert(html_result.include?('Raw Command Test'), 'HTML should include headline')
    assert(html_result.include?('Before raw command'), 'HTML should include before paragraph')
    assert(html_result.include?('After raw commands'), 'HTML should include after paragraph')
    assert(html_result.include?('bold'), 'HTML should include inline content')

    assert_not_nil(ast_root, 'Should have AST root')

    headline_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal(1, headline_nodes.size, 'Should have one headline')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert(paragraph_nodes.size >= 3, 'Should have multiple paragraphs processed via AST')

    middle_para = paragraph_nodes.find do |para|
      para.children.any? { |child| child.is_a?(ReVIEW::AST::InlineNode) && child.inline_type == :b }
    end
    assert_not_nil(middle_para, 'Should have paragraph with bold inline element')

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

    chapter_ast = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_ast.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter_ast)

    renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter_ast)
    html_result_ast = renderer.render(ast_root)

    assert(html_result_ast.include?('bold'), 'HTML should include bold content')
    assert(html_result_ast.include?('italic'), 'HTML should include italic content')
    assert(html_result_ast.include?('code'), 'HTML should include code content')
    assert(html_result_ast.include?('glossary'), 'HTML should include word expansion content')

    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }

    inline_types = []
    paragraph_nodes.each do |para|
      para.children.each do |child|
        if child.is_a?(ReVIEW::AST::InlineNode)
          inline_types << child.inline_type
        end
      end
    end

    expected_types = %i[b i code ruby href kw w wb]
    expected_types.each do |type|
      assert(inline_types.include?(type), "Should have inline type: #{type}")
    end

    simple_content = <<~EOB
      = Simple Test

      Text with @<b>{bold} and @<i>{italic}.
    EOB

    chapter_simple = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter_simple.content = simple_content

    simple_ast = ast_compiler.compile_to_ast(chapter_simple)
    simple_renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter_simple)
    result_simple = simple_renderer.render(simple_ast)

    ['<b>', '<i>'].each do |tag|
      assert(result_simple.include?(tag), "AST/Renderer system should produce #{tag}")
    end
  end
end
