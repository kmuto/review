# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestASTEmbed < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_embed_node_creation
    node = ReVIEW::AST::EmbedNode.new(
      location: ReVIEW::SnapshotLocation.new(nil, 0),
      embed_type: :block,
      lines: ['content line 1', 'content line 2'],
      arg: 'html'
    )

    hash = node.to_h
    assert_equal 'EmbedNode', hash[:type]
    assert_equal :block, hash[:embed_type]
    assert_equal ['content line 1', 'content line 2'], hash[:lines]
    assert_equal 'html', hash[:arg]
  end

  def test_embed_block_ast_processing
    content = <<~EOB
      = Chapter Title

      Normal paragraph before embed.

      //embed[html]{
      <div class="special">
      HTML content here
      </div>
      //}

      Paragraph after embed.
    EOB

    ast_root = compile_to_ast(content)

    embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_not_nil(embed_node, 'Should have embed node')
    assert_equal :block, embed_node.embed_type
    assert_equal ['html'], embed_node.target_builders
    assert(embed_node.content.include?('<div class="special">'), 'Should contain div')
    assert(embed_node.content.include?('HTML content here'), 'Should contain HTML content')
    assert(embed_node.content.include?('</div>'), 'Should contain closing div')
  end

  def test_embed_block_without_arg
    content = <<~EOB
      //embed{
      Raw content
      No builder filter
      //}
    EOB

    ast_root = compile_to_ast(content)

    embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_not_nil(embed_node)
    assert_equal :block, embed_node.embed_type
    assert_nil(embed_node.target_builders, 'Should have no target builders (applies to all)')
    assert(embed_node.content.include?('Raw content'), 'Should contain raw content')
    assert(embed_node.content.include?('No builder filter'), 'Should contain no builder filter text')
  end

  def test_inline_embed_ast_processing
    content = <<~EOB
      This paragraph has @<embed>{inline content} in it.
    EOB

    ast_root = compile_to_ast(content)

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(paragraph_node)

    embed_node = paragraph_node.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }
    assert_not_nil(embed_node, 'Should have inline embed node')
    assert_equal :inline, embed_node.embed_type
    assert_equal 'inline content', embed_node.arg

    # Inline Embed should not have lines
    assert_equal [], embed_node.lines
  end

  def test_inline_embed_with_builder_filter
    content = <<~EOB
      Text with @<embed>{|html|<strong>HTML only</strong>} content.
    EOB

    ast_root = compile_to_ast(content)

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    embed_node = paragraph_node.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }

    assert_not_nil(embed_node)
    assert_equal :inline, embed_node.embed_type
    assert_equal '|html|<strong>HTML only</strong>', embed_node.arg
  end

  def test_embed_output_compatibility
    content = <<~EOB
      Normal text @<embed>{inline embed} more text.

      //embed[html]{
      <div>Block embed content</div>
      //}
    EOB

    ast_root = compile_to_ast(content)

    paragraph_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    block_embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) && n.embed_type == :block }

    assert_not_nil(paragraph_node, 'Should have paragraph with inline embed')
    assert_not_nil(block_embed_node, 'Should have block embed node')

    inline_embed = paragraph_node.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) && n.embed_type == :inline }
    assert_not_nil(inline_embed, 'Should have inline embed in paragraph')
    assert_equal 'inline embed', inline_embed.arg

    assert_equal ['html'], block_embed_node.target_builders
    assert_equal '<div>Block embed content</div>', block_embed_node.content
  end

  def test_mixed_content_with_embed
    content = <<~EOB
      = Chapter with Embeds

      This paragraph has @<b>{bold} and @<embed>{inline embed} elements.

      //embed[html]{
      <div class="example">
      <p>Some HTML content</p>
      </div>
      //}

      Another paragraph after the embed block.
    EOB

    ast_root = compile_to_ast(content)

    headline_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    paragraph_nodes = ast_root.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    embed_node = ast_root.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) }

    assert_not_nil(headline_node)
    assert_equal 2, paragraph_nodes.size
    assert_not_nil(embed_node)
    assert_equal :block, embed_node.embed_type

    first_para = paragraph_nodes[0]
    bold_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :b }
    inline_embed_node = first_para.children.find { |n| n.is_a?(ReVIEW::AST::EmbedNode) && n.embed_type == :inline }

    assert_not_nil(bold_node)
    assert_not_nil(inline_embed_node)
  end

  private

  def compile_to_ast(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_compiler.compile_to_ast(chapter)
  end
end
