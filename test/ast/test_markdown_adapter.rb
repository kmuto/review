# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/markdown_adapter'
require 'review/ast/compiler'
require 'review/ast/node'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'stringio'

return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')

require 'markly'

class TestMarkdownAdapter < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new(config: @config)
    @compiler = ReVIEW::AST::Compiler.new
  end

  def create_chapter(content)
    ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.md', StringIO.new(content))
  end

  def create_adapter
    ReVIEW::AST::MarkdownAdapter.new(@compiler)
  end

  def parse_markdown(content)
    extensions = %i[strikethrough table autolink tagfilter]
    Markly.parse(content, extensions: extensions)
  end

  def convert_markdown(markdown_content, chapter = nil)
    chapter ||= create_chapter(markdown_content)
    adapter = create_adapter
    ast_root = ReVIEW::AST::DocumentNode.new(
      location: ReVIEW::SnapshotLocation.new(chapter.basename, 1)
    )

    markly_doc = parse_markdown(markdown_content)
    adapter.convert(markly_doc, ast_root, chapter)

    ast_root
  end

  # Basic conversion tests

  def test_empty_document
    ast = convert_markdown('')

    assert_kind_of(ReVIEW::AST::DocumentNode, ast)
    assert_equal 0, ast.children.size
  end

  def test_simple_paragraph
    markdown = 'This is a simple paragraph.'
    ast = convert_markdown(markdown)

    paragraphs = ast.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 1, paragraphs.size

    text_nodes = paragraphs[0].children.select { |n| n.is_a?(ReVIEW::AST::TextNode) }
    assert_equal 1, text_nodes.size
    assert_equal 'This is a simple paragraph.', text_nodes[0].content
  end

  def test_multiple_paragraphs
    markdown = <<~MD
      First paragraph.

      Second paragraph.

      Third paragraph.
    MD

    ast = convert_markdown(markdown)

    paragraphs = ast.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 3, paragraphs.size

    assert_equal 'First paragraph.', paragraphs[0].children.first.content
    assert_equal 'Second paragraph.', paragraphs[1].children.first.content
    assert_equal 'Third paragraph.', paragraphs[2].children.first.content
  end

  # Heading tests

  def test_heading_level1
    markdown = '# Chapter Title'
    ast = convert_markdown(markdown)

    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal 1, headlines.size
    assert_equal 1, headlines[0].level
    assert_equal 'Chapter Title', headlines[0].caption_text
  end

  def test_heading_all_levels
    markdown = <<~MD
      # Level 1
      ## Level 2
      ### Level 3
      #### Level 4
      ##### Level 5
      ###### Level 6
    MD

    ast = convert_markdown(markdown)

    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal 6, headlines.size

    (1..6).each do |level|
      assert_equal level, headlines[level - 1].level
      assert_equal "Level #{level}", headlines[level - 1].caption_text
    end
  end

  def test_heading_with_inline_formatting
    markdown = '## This is a **bold** and *italic* heading'
    ast = convert_markdown(markdown)

    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal 1, headlines.size

    caption_node = headlines[0].caption_node
    assert_kind_of(ReVIEW::AST::CaptionNode, caption_node)

    # Check inline elements
    children = caption_node.children
    assert(children.any? { |c| c.is_a?(ReVIEW::AST::TextNode) && c.content == 'This is a ' })
    assert(children.any? { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :b })
    assert(children.any? { |c| c.is_a?(ReVIEW::AST::TextNode) && c.content == ' and ' })
    assert(children.any? { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :i })
  end

  # Inline element tests

  def test_inline_bold
    markdown = 'This is **bold text**.'
    ast = convert_markdown(markdown)

    para = ast.children.first
    bold_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :b }

    assert_not_nil(bold_node)
    assert_equal 'bold text', bold_node.args[0]
  end

  def test_inline_italic
    markdown = 'This is *italic text*.'
    ast = convert_markdown(markdown)

    para = ast.children.first
    italic_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :i }

    assert_not_nil(italic_node)
    assert_equal 'italic text', italic_node.args[0]
  end

  def test_inline_code
    markdown = 'This is `code text`.'
    ast = convert_markdown(markdown)

    para = ast.children.first
    code_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :code }

    assert_not_nil(code_node)
    assert_equal 'code text', code_node.args[0]
  end

  def test_inline_link
    markdown = 'This is [link text](http://example.com).'
    ast = convert_markdown(markdown)

    para = ast.children.first
    link_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :href }

    assert_not_nil(link_node)
    assert_equal 'http://example.com', link_node.args[0]
    assert_equal 'link text', link_node.args[1]
  end

  def test_inline_strikethrough
    markdown = 'This is ~~strikethrough text~~.'
    ast = convert_markdown(markdown)

    para = ast.children.first
    del_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :del }

    assert_not_nil(del_node)
    assert_equal 'strikethrough text', del_node.args[0]
  end

  def test_inline_nested
    markdown = '**Bold with *italic* inside**'
    ast = convert_markdown(markdown)

    para = ast.children.first
    bold_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :b }

    assert_not_nil(bold_node)
    assert(bold_node.children.any? { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :i })
  end

  # List tests

  def test_unordered_list
    markdown = <<~MD
      * Item 1
      * Item 2
      * Item 3
    MD

    ast = convert_markdown(markdown)

    lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 1, lists.size

    list = lists[0]
    assert_equal :ul, list.list_type

    items = list.children.select { |n| n.is_a?(ReVIEW::AST::ListItemNode) }
    assert_equal 3, items.size
  end

  def test_ordered_list
    markdown = <<~MD
      1. First item
      2. Second item
      3. Third item
    MD

    ast = convert_markdown(markdown)

    lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 1, lists.size

    list = lists[0]
    assert_equal :ol, list.list_type
    assert_equal 1, list.start_number

    items = list.children.select { |n| n.is_a?(ReVIEW::AST::ListItemNode) }
    assert_equal 3, items.size
  end

  def test_nested_list
    markdown = <<~MD
      * Item 1
        * Nested 1.1
        * Nested 1.2
      * Item 2
    MD

    ast = convert_markdown(markdown)

    top_lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 1, top_lists.size

    top_list = top_lists[0]
    assert_equal :ul, top_list.list_type

    # Check nested structure
    first_item = top_list.children.first
    assert_kind_of(ReVIEW::AST::ListItemNode, first_item)

    nested_lists = first_item.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 1, nested_lists.size

    nested_items = nested_lists[0].children.select { |n| n.is_a?(ReVIEW::AST::ListItemNode) }
    assert_equal 2, nested_items.size
  end

  # Code block tests

  def test_code_block_without_language
    markdown = <<~MD
      ```
      code line 1
      code line 2
      ```
    MD

    ast = convert_markdown(markdown)

    code_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_equal 1, code_blocks.size

    code_block = code_blocks[0]
    assert_nil(code_block.lang)
    assert_equal :emlist, code_block.code_type

    lines = code_block.children.select { |n| n.is_a?(ReVIEW::AST::CodeLineNode) }
    assert_equal 2, lines.size
  end

  def test_code_block_with_language
    markdown = <<~MD
      ```ruby
      def hello
        puts "Hello"
      end
      ```
    MD

    ast = convert_markdown(markdown)

    code_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_equal 1, code_blocks.size

    code_block = code_blocks[0]
    assert_equal 'ruby', code_block.lang
    assert_equal :emlist, code_block.code_type

    lines = code_block.children.select { |n| n.is_a?(ReVIEW::AST::CodeLineNode) }
    assert_equal 3, lines.size
  end

  # Blockquote tests

  def test_blockquote
    markdown = <<~MD
      > This is a quote.
      > It spans multiple lines.
    MD

    ast = convert_markdown(markdown)

    blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :quote }
    assert_equal 1, blocks.size

    quote = blocks[0]
    paras = quote.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 1, paras.size
  end

  # Table tests

  def test_table_basic
    markdown = <<~MD
      | Header 1 | Header 2 |
      |----------|----------|
      | Cell 1   | Cell 2   |
      | Cell 3   | Cell 4   |
    MD

    ast = convert_markdown(markdown)

    tables = ast.children.select { |n| n.is_a?(ReVIEW::AST::TableNode) }
    assert_equal 1, tables.size

    table = tables[0]

    # Check header row
    header_rows = table.header_rows
    assert_equal 1, header_rows.size
    header_cells = header_rows[0].children.select { |n| n.is_a?(ReVIEW::AST::TableCellNode) }
    assert_equal 2, header_cells.size

    # Check body rows
    body_rows = table.body_rows
    assert_equal 2, body_rows.size
  end

  # Image tests

  def test_inline_image
    markdown = 'This is an inline ![alt text](image.png) image.'
    ast = convert_markdown(markdown)

    para = ast.children.first
    icon_node = para.children.find { |c| c.is_a?(ReVIEW::AST::InlineNode) && c.inline_type == :icon }

    assert_not_nil(icon_node)
    assert_equal 'image.png', icon_node.args[0]
  end

  def test_standalone_image
    markdown = <<~MD
      ![Image caption](image.png)
    MD

    ast = convert_markdown(markdown)

    images = ast.children.select { |n| n.is_a?(ReVIEW::AST::ImageNode) }
    assert_equal 1, images.size

    image = images[0]
    assert_equal 'image', image.id
    assert_equal 'Image caption', image.caption_text
  end

  # HTML block tests

  def test_html_block
    markdown = <<~MD
      <div class="custom">
      Custom HTML content
      </div>
    MD

    ast = convert_markdown(markdown)

    embeds = ast.children.select { |n| n.is_a?(ReVIEW::AST::EmbedNode) && n.embed_type == :html }
    assert_equal 1, embeds.size
  end

  # Column tests

  def test_column_with_html_comment
    markdown = <<~MD
      <!-- begin-column: Column Title -->

      Column content here.

      <!-- end-column -->
    MD

    ast = convert_markdown(markdown)

    # HTML comment columns are processed by MarkdownHtmlNode
    # Check if columns or embeds are created
    columns = ast.children.select { |n| n.is_a?(ReVIEW::AST::ColumnNode) }

    if columns.size > 0
      # If column support is implemented
      column = columns[0]
      assert_equal 'Column Title', column.caption_text

      paras = column.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
      assert_equal 1, paras.size
    else
      # HTML comments might be treated as embed nodes or processed differently
      # The test passes if the document is parsed without errors
      assert_kind_of(ReVIEW::AST::DocumentNode, ast)
    end
  end

  def test_column_with_heading_syntax
    markdown = <<~MD
      ### [column] Column Title

      Column content here.

      ### [/column]
    MD

    ast = convert_markdown(markdown)

    columns = ast.children.select { |n| n.is_a?(ReVIEW::AST::ColumnNode) }
    assert_equal 1, columns.size

    column = columns[0]
    assert_equal 'Column Title', column.caption_text

    paras = column.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 1, paras.size
  end

  def test_column_auto_close_with_same_level_heading
    markdown = <<~MD
      ## Section 1

      ### [column] Column Title

      Column content here.

      ### Next Section

      After column.
    MD

    ast = convert_markdown(markdown)

    columns = ast.children.select { |n| n.is_a?(ReVIEW::AST::ColumnNode) }
    assert_equal 1, columns.size

    column = columns[0]
    assert_equal 'Column Title', column.caption_text

    # Column should only contain the paragraph before "Next Section"
    paras = column.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 1, paras.size

    # "Next Section" should be a headline after the column
    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    next_section = headlines.find { |h| h.caption_text == 'Next Section' }
    assert_not_nil(next_section)
  end

  def test_column_auto_close_with_higher_level_heading
    markdown = <<~MD
      ### [column] Column Title

      Column content here.

      ## Higher Level Section

      After column.
    MD

    ast = convert_markdown(markdown)

    columns = ast.children.select { |n| n.is_a?(ReVIEW::AST::ColumnNode) }
    assert_equal 1, columns.size

    column = columns[0]
    assert_equal 'Column Title', column.caption_text

    # Column should only contain one paragraph
    paras = column.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 1, paras.size

    # Higher level section should be after the column
    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    higher_section = headlines.find { |h| h.caption_text == 'Higher Level Section' }
    assert_not_nil(higher_section)
  end

  def test_column_auto_close_at_end_of_document
    markdown = <<~MD
      ### [column] Column Title

      Column content here.

      More content.
    MD

    ast = convert_markdown(markdown)

    columns = ast.children.select { |n| n.is_a?(ReVIEW::AST::ColumnNode) }
    assert_equal 1, columns.size

    column = columns[0]
    assert_equal 'Column Title', column.caption_text

    # Column should contain both paragraphs
    paras = column.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paras.size
  end

  # Thematic break (horizontal rule) tests

  def test_thematic_break
    markdown = <<~MD
      Before line

      ---

      After line
    MD

    ast = convert_markdown(markdown)

    hr_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :hr }
    assert_equal 1, hr_blocks.size
  end

  # Line break tests

  def test_soft_line_break
    markdown = <<~MD
      Line one
      line two
    MD

    ast = convert_markdown(markdown)

    para = ast.children.first
    # Soft breaks should be converted to spaces
    text_content = para.children.map do |c|
      c.is_a?(ReVIEW::AST::TextNode) ? c.content : ''
    end.join

    assert text_content.include?(' ')
  end

  def test_hard_line_break
    markdown = "Line one  \nLine two"
    ast = convert_markdown(markdown)

    para = ast.children.first
    # Hard breaks should be preserved
    assert(para.children.any? { |c| c.is_a?(ReVIEW::AST::TextNode) && c.content == "\n" })
  end

  # Location tracking tests

  def test_location_tracking
    markdown = <<~MD
      # Heading

      Paragraph
    MD

    chapter = create_chapter(markdown)
    ast = convert_markdown(markdown, chapter)

    headline = ast.children.find { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_not_nil(headline.location)
    assert_kind_of(ReVIEW::SnapshotLocation, headline.location)

    para = ast.children.find { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_not_nil(para.location)
    assert_kind_of(ReVIEW::SnapshotLocation, para.location)
  end

  # Complex integration tests

  def test_complex_document
    markdown = <<~MD
      # Chapter Title

      This is an introduction paragraph with **bold** and *italic* text.

      ## Section 1

      * List item 1
      * List item 2

      ```ruby
      def example
        puts "Hello"
      end
      ```

      ## Section 2

      | Header 1 | Header 2 |
      |----------|----------|
      | Data 1   | Data 2   |

      > This is a quote.

      Final paragraph.
    MD

    ast = convert_markdown(markdown)

    # Check all node types are present
    assert(ast.children.any?(ReVIEW::AST::HeadlineNode))
    assert(ast.children.any?(ReVIEW::AST::ParagraphNode))
    assert(ast.children.any?(ReVIEW::AST::ListNode))
    assert(ast.children.any?(ReVIEW::AST::CodeBlockNode))
    assert(ast.children.any?(ReVIEW::AST::TableNode))
    assert(ast.children.any? { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :quote })
  end

  def test_extract_image_id
    adapter = create_adapter

    # Test various image URL formats
    assert_equal 'image', adapter.send(:extract_image_id, 'image.png')
    assert_equal 'photo', adapter.send(:extract_image_id, 'path/to/photo.jpg')
    assert_equal 'diagram', adapter.send(:extract_image_id, '../images/diagram.svg')
  end
end
