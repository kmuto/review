# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/markdown_compiler'
require 'review/ast/node'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'stringio'

class TestMarkdownCompiler < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new(config: @config)
    @compiler = ReVIEW::AST::MarkdownCompiler.new
  end

  def create_chapter(content)
    ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.md', StringIO.new(content))
  end

  def test_heading_conversion
    markdown = <<~MD
      # Chapter Title
      
      ## Section 1.1
      
      ### Subsection 1.1.1
      
      #### Level 4
      
      ##### Level 5
      
      ###### Level 6
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    assert_kind_of(ReVIEW::AST::DocumentNode, ast)

    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    assert_equal 6, headlines.size

    assert_equal 1, headlines[0].level
    assert_equal 'Chapter Title', headlines[0].caption_node.children.first.content

    assert_equal 2, headlines[1].level
    assert_equal 'Section 1.1', headlines[1].caption_node.children.first.content

    assert_equal 3, headlines[2].level
    assert_equal 4, headlines[3].level
    assert_equal 5, headlines[4].level
    assert_equal 6, headlines[5].level
  end

  def test_paragraph_conversion
    markdown = <<~MD
      This is a paragraph.
      
      This is another paragraph with **bold** and *italic* text.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    paragraphs = ast.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paragraphs.size

    # First paragraph
    assert_equal 'This is a paragraph.', paragraphs[0].children.first.content

    # Second paragraph with inline elements
    para2_children = paragraphs[1].children
    assert_equal 'This is another paragraph with ', para2_children[0].content
    assert_kind_of(ReVIEW::AST::InlineNode, para2_children[1])
    assert_equal :b, para2_children[1].inline_type
    assert_equal ' and ', para2_children[2].content
    assert_kind_of(ReVIEW::AST::InlineNode, para2_children[3])
    assert_equal :i, para2_children[3].inline_type
  end

  def test_list_conversion
    markdown = <<~MD
      ## Lists
      
      * Item 1
      * Item 2
        * Nested item
      * Item 3
      
      1. First
      2. Second
      3. Third
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) }
    assert_equal 2, lists.size

    # Unordered list
    ul = lists[0]
    assert_kind_of(ReVIEW::AST::ListNode, ul)
    assert ul.ul?
    assert_equal 3, ul.children.size

    # Check first item
    assert_kind_of(ReVIEW::AST::ListItemNode, ul.children[0])
    assert_equal 'Item 1', ul.children[0].children.first.content

    # Ordered list
    ol = lists[1]
    assert_kind_of(ReVIEW::AST::ListNode, ol)
    assert ol.ol?
    assert_equal 3, ol.children.size
    assert_equal 1, ol.start_number
  end

  def test_code_block_conversion
    markdown = <<~MD
      ```ruby
      def hello
        puts "Hello, World!"
      end
      ```
      
      ```
      Plain code block
      ```
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    code_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_equal 2, code_blocks.size

    # Ruby code block
    ruby_block = code_blocks[0]
    assert_equal 'ruby', ruby_block.lang
    assert_equal :emlist, ruby_block.code_type
    assert_equal 3, ruby_block.children.size
    assert_equal 'def hello', ruby_block.children[0].children.first.content

    # Plain code block
    plain_block = code_blocks[1]
    assert_nil(plain_block.lang)
  end

  def test_blockquote_conversion
    markdown = <<~MD
      > This is a quote.
      > 
      > With multiple lines.
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    quotes = ast.children.select { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :quote }
    assert_equal 1, quotes.size

    quote = quotes[0]
    paragraphs = quote.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    assert_equal 2, paragraphs.size
  end

  def test_inline_code_conversion
    markdown = 'Use `code` inline.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    para = ast.children.first
    assert_kind_of(ReVIEW::AST::ParagraphNode, para)

    inline_code = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :code }
    assert_not_nil(inline_code)
    assert_equal 'code', inline_code.args[0]
  end

  def test_link_conversion
    markdown = 'Visit [Example](https://example.com) for more info.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    para = ast.children.first
    link = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :href }
    assert_not_nil(link)
    assert_equal 'https://example.com', link.args[0]
    assert_equal 'Example', link.args[1]
  end

  def test_image_conversion
    markdown = '![Alt text](image.png)'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # Standalone images are now processed as ImageNode instead of inline icon
    image = ast.children.find { |n| n.is_a?(ReVIEW::AST::ImageNode) }
    assert_not_nil(image)
    assert_equal 'image', image.id
    assert_equal 'Alt text', image.caption_node.children.first.content
  end

  def test_inline_image_conversion
    markdown = 'This is text with ![inline image](icon.png) in the middle.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # Inline images (not standalone) should still be processed as icon
    para = ast.children.first
    image = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :icon }
    assert_not_nil(image)
    assert_equal 'icon.png', image.args[0]
  end

  def test_table_conversion
    markdown = <<~MD
      | Header 1 | Header 2 |
      |----------|----------|
      | Cell 1   | Cell 2   |
      | Cell 3   | Cell 4   |
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    tables = ast.children.select { |n| n.is_a?(ReVIEW::AST::TableNode) }
    assert_equal 1, tables.size

    table = tables[0]
    rows = table.children
    assert_equal 3, rows.size # Header + 2 body rows

    # Check header row
    header_row = rows[0]
    assert_equal :header, header_row.row_type
    assert_equal 2, header_row.children.size

    # Check body rows
    assert_equal :body, rows[1].row_type
    assert_equal :body, rows[2].row_type
  end

  def test_strikethrough_conversion
    markdown = 'This is ~~strikethrough~~ text.'

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    para = ast.children.first
    del = para.children.find { |n| n.is_a?(ReVIEW::AST::InlineNode) && n.inline_type == :del }
    assert_not_nil(del)
    assert_equal 'strikethrough', del.args[0]
  end

  def test_horizontal_rule_conversion
    markdown = <<~MD
      Text before
      
      ---
      
      Text after
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    hr = ast.children.find { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :hr }
    assert_not_nil(hr)
  end

  def test_complex_document
    markdown = <<~MD
      # Main Title

      This is the introduction with **bold** and *italic* text.

      ## Features

      * Feature 1 with `inline code`
      * Feature 2 with [link](https://example.com)
      * Feature 3

      ### Code Example

      ```ruby
      class Example
        def initialize
          @value = 42
        end
      end
      ```

      ## Conclusion

      > This is a famous quote.
      >
      > -- Author
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # Verify overall structure
    assert_kind_of(ReVIEW::AST::DocumentNode, ast)
    assert ast.children.size > 0

    # Count different node types
    headlines = ast.children.select { |n| n.is_a?(ReVIEW::AST::HeadlineNode) }
    paragraphs = ast.children.select { |n| n.is_a?(ReVIEW::AST::ParagraphNode) }
    lists = ast.children.select { |n| n.is_a?(ReVIEW::AST::ListNode) && n.ul? }
    code_blocks = ast.children.select { |n| n.is_a?(ReVIEW::AST::CodeBlockNode) }
    quotes = ast.children.select { |n| n.is_a?(ReVIEW::AST::BlockNode) && n.block_type == :quote }

    assert_equal 4, headlines.size # Main Title, Features, Code Example, Conclusion
    assert_equal 1, paragraphs.size  # Introduction
    assert_equal 1, lists.size       # Feature list
    assert_equal 1, code_blocks.size # Ruby code
    assert_equal 1, quotes.size      # Famous quote
  end

  # Re:VIEW拡張機能のテスト: ID指定と参照

  def test_image_with_attribute_block_next_line
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    images = find_nodes(ast, ReVIEW::AST::ImageNode)
    assert_equal 1, images.size

    image = images.first
    assert_equal 'fig-sample', image.id
    assert_equal 'Sample Figure', image.caption_node.children.first.content
  end

  def test_image_with_attribute_block_same_line
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png){#fig-sample caption="Sample Figure"}
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    images = find_nodes(ast, ReVIEW::AST::ImageNode)
    assert_equal 1, images.size

    image = images.first
    assert_equal 'fig-sample', image.id
    assert_equal 'Sample Figure', image.caption_node.children.first.content
  end

  def test_image_with_id_only
    markdown = <<~MD
      ![Sample Image](images/sample.png)
      {#fig-sample}
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    images = find_nodes(ast, ReVIEW::AST::ImageNode)
    assert_equal 1, images.size

    image = images.first
    assert_equal 'fig-sample', image.id
    # altテキストがキャプションになる
    assert_equal 'Sample Image', image.caption_node.children.first.content
  end

  def test_table_with_attribute_block
    markdown = <<~MD
      # Test Chapter

      | Column 1 | Column 2 |
      |----------|----------|
      | Data 1   | Data 2   |
      {#table-sample caption="Sample Table"}
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    tables = find_nodes(ast, ReVIEW::AST::TableNode)
    assert_equal 1, tables.size

    table = tables.first
    assert_equal 'table-sample', table.id
    assert_equal 'Sample Table', table.caption_node.children.first.content
  end

  def test_code_block_with_attribute_block
    markdown = <<~MD
      # Test Chapter

      ```ruby {#list-sample caption="Sample Code"}
      def hello
        puts "Hello, World!"
      end
      ```
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    code_blocks = find_nodes(ast, ReVIEW::AST::CodeBlockNode)
    assert_equal 1, code_blocks.size

    code_block = code_blocks.first
    assert_equal 'list-sample', code_block.id
    assert_equal :list, code_block.code_type
    assert_equal 'Sample Code', code_block.caption_node.children.first.content
  end

  def test_image_reference
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}

      @<img>{fig-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)
    img_refs = inline_nodes.select { |n| n.inline_type == :img }

    assert_equal 1, img_refs.size

    img_ref = img_refs.first
    assert_equal :img, img_ref.inline_type
    assert_equal ['fig-sample'], img_ref.args

    # ReferenceNodeが含まれていることを確認
    ref_node = img_ref.children.first
    assert_kind_of(ReVIEW::AST::ReferenceNode, ref_node)
    assert_equal 'fig-sample', ref_node.ref_id
  end

  def test_list_reference
    markdown = <<~MD
      # Test Chapter

      ```ruby {#list-sample caption="Sample Code"}
      puts "Hello"
      ```

      @<list>{list-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)
    list_refs = inline_nodes.select { |n| n.inline_type == :list }

    assert_equal 1, list_refs.size

    list_ref = list_refs.first
    assert_equal :list, list_ref.inline_type
    assert_equal ['list-sample'], list_ref.args

    ref_node = list_ref.children.first
    assert_kind_of(ReVIEW::AST::ReferenceNode, ref_node)
    assert_equal 'list-sample', ref_node.ref_id
  end

  def test_table_reference
    markdown = <<~MD
      # Test Chapter

      | A | B |
      |---|---|
      | 1 | 2 |
      {#table-sample caption="Sample Table"}

      @<table>{table-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)
    table_refs = inline_nodes.select { |n| n.inline_type == :table }

    assert_equal 1, table_refs.size

    table_ref = table_refs.first
    assert_equal :table, table_ref.inline_type
    assert_equal ['table-sample'], table_ref.args

    ref_node = table_ref.children.first
    assert_kind_of(ReVIEW::AST::ReferenceNode, ref_node)
    assert_equal 'table-sample', ref_node.ref_id
  end

  def test_multiple_elements_and_references
    markdown = <<~MD
      # Test Chapter

      ## 画像

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}

      図@<img>{fig-sample}を参照してください。

      ## コード

      ```ruby {#list-sample caption="Sample Code"}
      def hello
        puts "Hello"
      end
      ```

      リスト@<list>{list-sample}を参照してください。

      ## テーブル

      | Column 1 | Column 2 |
      |----------|----------|
      | Data 1   | Data 2   |
      {#table-sample caption="Sample Table"}

      表@<table>{table-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    # 各要素が正しく生成されていることを確認
    images = find_nodes(ast, ReVIEW::AST::ImageNode)
    assert_equal 1, images.size
    assert_equal 'fig-sample', images.first.id

    code_blocks = find_nodes(ast, ReVIEW::AST::CodeBlockNode)
    code_blocks_with_id = code_blocks.select(&:id)
    assert_equal 1, code_blocks_with_id.size
    assert_equal 'list-sample', code_blocks_with_id.first.id

    tables = find_nodes(ast, ReVIEW::AST::TableNode)
    assert_equal 1, tables.size
    assert_equal 'table-sample', tables.first.id

    # 各参照が正しく生成されていることを確認
    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)

    img_refs = inline_nodes.select { |n| n.inline_type == :img }
    assert_equal 1, img_refs.size

    list_refs = inline_nodes.select { |n| n.inline_type == :list }
    assert_equal 1, list_refs.size

    table_refs = inline_nodes.select { |n| n.inline_type == :table }
    assert_equal 1, table_refs.size
  end

  def test_softbreak_does_not_interfere_with_attribute_block
    # Marklyは画像の直後に改行があるとsoftbreakノードを挿入する
    # このテストは、そのsoftbreakノードが属性ブロックの認識を妨げないことを確認
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    images = find_nodes(ast, ReVIEW::AST::ImageNode)
    assert_equal 1, images.size, '画像がImageNodeとして認識されていません'

    image = images.first
    assert_equal 'fig-sample', image.id, 'IDが正しく設定されていません'
    assert_equal 'Sample Figure', image.caption_node.children.first.content, 'キャプションが正しく設定されていません'
  end

  def test_chapter_reference
    markdown = <<~MD
      # Test Chapter

      @<chap>{chapter2}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)
    chap_refs = inline_nodes.select { |n| n.inline_type == :chap }

    assert_equal 1, chap_refs.size

    chap_ref = chap_refs.first
    assert_equal :chap, chap_ref.inline_type
    assert_equal ['chapter2'], chap_ref.args

    ref_node = chap_ref.children.first
    assert_kind_of(ReVIEW::AST::ReferenceNode, ref_node)
    assert_equal 'chapter2', ref_node.ref_id
  end

  def test_title_reference
    markdown = <<~MD
      # Test Chapter

      @<title>{chapter2}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)
    title_refs = inline_nodes.select { |n| n.inline_type == :title }

    assert_equal 1, title_refs.size

    title_ref = title_refs.first
    assert_equal :title, title_ref.inline_type
    assert_equal ['chapter2'], title_ref.args

    ref_node = title_ref.children.first
    assert_kind_of(ReVIEW::AST::ReferenceNode, ref_node)
    assert_equal 'chapter2', ref_node.ref_id
  end

  def test_chapref_reference
    markdown = <<~MD
      # Test Chapter

      @<chapref>{chapter2}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    inline_nodes = find_nodes(ast, ReVIEW::AST::InlineNode)
    chapref_refs = inline_nodes.select { |n| n.inline_type == :chapref }

    assert_equal 1, chapref_refs.size

    chapref_ref = chapref_refs.first
    assert_equal :chapref, chapref_ref.inline_type
    assert_equal ['chapter2'], chapref_ref.args

    ref_node = chapref_ref.children.first
    assert_kind_of(ReVIEW::AST::ReferenceNode, ref_node)
    assert_equal 'chapter2', ref_node.ref_id
  end

  private

  # ASTツリーから特定のノードタイプを再帰的に検索
  def find_nodes(node, node_class, found = [])
    found << node if node.is_a?(node_class)

    if node.respond_to?(:children)
      node.children.each { |child| find_nodes(child, node_class, found) }
    end

    found
  end
end
