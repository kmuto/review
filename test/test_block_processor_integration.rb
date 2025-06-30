# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/compiler'
require 'review/ast/block_processor'
require 'review/ast/block_data'
require 'review/book'
require 'review/book/chapter'
require 'stringio'

class TestBlockProcessorIntegration < Test::Unit::TestCase
  include ReVIEW

  def setup
    @config = Configure.values
    @config['language'] = 'ja'
    @book = Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    I18n.setup(@config['language'])
  end

  def test_simple_block_processing
    content = <<~EOB
      = Test Chapter

      //list[example][サンプルコード]{
      def hello
        puts "world"
      end
      //}

      段落テキスト
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    # ASTの構造を確認
    assert_equal AST::DocumentNode, ast.class
    assert_equal 3, ast.children.size

    # 見出し
    headline = ast.children[0]
    assert_equal AST::HeadlineNode, headline.class
    assert_equal 1, headline.level

    # コードブロック
    code_block = ast.children[1]
    assert_equal AST::CodeBlockNode, code_block.class
    assert_equal 'example', code_block.id
    assert_equal :list, code_block.code_type
    assert_equal 3, code_block.children.size # 3行のコード

    # 段落
    paragraph = ast.children[2]
    assert_equal AST::ParagraphNode, paragraph.class
  end

  def test_nested_block_processing
    content = <<~EOB
      = Test Chapter

      //note[注意]{
      これは注意書きです。

      //list[nested][ネストしたコード]{
      def nested_method
        puts "nested"
      end
      //}

      注意書きの続き。
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    # ASTの構造を確認
    assert_equal AST::DocumentNode, ast.class
    assert_equal 2, ast.children.size

    # 見出し
    headline = ast.children[0]
    assert_equal AST::HeadlineNode, headline.class

    # ミニコラム（ネスト構造を含む）
    minicolumn = ast.children[1]
    assert_equal AST::MinicolumnNode, minicolumn.class
    assert_equal :note, minicolumn.minicolumn_type

    # ミニコラム内にネストしたコードブロックが含まれることを確認
    # 構造化コンテンツ処理により、段落とコードブロックが子要素として含まれる
    assert(minicolumn.children.any?(AST::CodeBlockNode))

    # ネストしたコードブロックの確認
    nested_code = minicolumn.children.find { |child| child.is_a?(AST::CodeBlockNode) }
    assert_equal 'nested', nested_code.id
    assert_equal :list, nested_code.code_type
  end

  def test_multiple_nested_blocks
    content = <<~EOB
      //box[テストボックス]{
      ボックスの説明

      //list[code1][最初のコード]{
      puts "first"
      //}

      中間テキスト

      //list[code2][二番目のコード]{
      puts "second"
      //}

      最後のテキスト
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    # ボックスブロックの確認
    box_block = ast.children[0]
    assert_equal AST::BlockNode, box_block.class
    assert_equal :box, box_block.block_type

    # ネストしたコードブロックが2つ含まれることを確認
    code_blocks = box_block.children.select { |child| child.is_a?(AST::CodeBlockNode) }
    assert_equal 2, code_blocks.size
    assert_equal 'code1', code_blocks[0].id
    assert_equal 'code2', code_blocks[1].id
  end

  def test_block_error_handling_unclosed_block
    content = <<~EOB
      //list[example][サンプル]{
      def hello
        puts "world"
      # //} が欠けている
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new

    assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end
  end

  def test_block_error_handling_invalid_syntax
    content = <<~EOB
      //invalid_command_name{
      content
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new

    assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end
  end

  def test_block_error_handling_nested_block_error
    content = <<~EOB
      //note[注意]{
      正常なテキスト

      //list[broken][壊れたコード]{
      def method
        # //} が欠けている - ネストエラー
      
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new

    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    # ネストブロック内のエラーであることがメッセージに含まれる
    assert_include(error.message.downcase, 'unclosed')
  end

  def test_image_block_processing
    content = <<~EOB
      //image[sample][サンプル画像][scale=0.5]{
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    image_node = ast.children[0]
    assert_equal AST::ImageNode, image_node.class
    assert_equal 'sample', image_node.id
    assert_equal 'scale=0.5', image_node.metric
    assert_equal :image, image_node.image_type
  end

  def test_table_block_processing
    content = <<~EOB
      //table[data][サンプルデータ]{
      名前	年齢
      ------------
      Alice	25
      Bob	30
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    table_node = ast.children[0]
    assert_equal AST::TableNode, table_node.class
    assert_equal 'data', table_node.id
    assert_equal :table, table_node.table_type
    assert_equal 1, table_node.header_rows.size
    assert_equal 2, table_node.body_rows.size
  end

  def test_minicolumn_with_structured_content
    content = <<~EOB
      //tip[ヒント]{
      基本的なヒント

       * リスト項目1
       * リスト項目2

      追加説明
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    tip_node = ast.children[0]
    assert_equal AST::MinicolumnNode, tip_node.class
    assert_equal :tip, tip_node.minicolumn_type

    # 構造化コンテンツ（段落、リスト、段落）が含まれることを確認
    assert(tip_node.children.any?(AST::ParagraphNode))
    assert(tip_node.children.any?(AST::ListNode))
  end

  def test_embed_block_processing
    content = <<~EOB
      //embed[html]{
      <div class="custom">
        <p>HTML content</p>
      </div>
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    embed_node = ast.children[0]
    assert_equal AST::EmbedNode, embed_node.class
    assert_equal :block, embed_node.embed_type
    assert_equal 'html', embed_node.arg
    assert_equal 3, embed_node.lines.size
  end

  def test_texequation_block_processing
    content = <<~EOB
      //texequation[eq1][数式]{
      E = mc^2
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    compiler = AST::Compiler.new
    ast = compiler.compile_to_ast(chapter)

    equation_node = ast.children[0]
    assert_equal AST::TexEquationNode, equation_node.class
    assert_equal 'eq1', equation_node.id
    assert_include(equation_node.content, 'E = mc^2')
  end
end
