# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/book'
require 'review/book/chapter'
require 'stringio'

class TestNestedBlockErrorHandling < Test::Unit::TestCase
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

  def create_chapter(content)
    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content
    chapter
  end

  def test_unclosed_parent_block
    content = <<~EOB
      //note[注意]{
      注意書きです。
      # //} が欠けている
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    assert_include(error.message, 'Unclosed block //note')
    assert_include(error.message, 'line')
  end

  def test_unclosed_nested_block
    content = <<~EOB
      //note[注意]{
      注意書きです。

      //list[example][サンプル]{
      def hello
        puts "world"
      # //} が欠けている - ネストブロックが未閉
      
      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    # ネストブロック内でのエラーメッセージを確認（どちらかのブロックが未閉）
    assert(error.message.include?('Unclosed block //list') || error.message.include?('Unclosed block //note'))
  end

  def test_extra_closing_tag
    content = <<~EOB
      //note[注意]{
      注意書きです。
      //}
      //} 
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    # 余分な//}はブロック終了子エラーとなる
    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    assert_include(error.message, 'Unexpected block terminator')
  end

  def test_invalid_block_command_syntax
    content = <<~EOB
      //123invalid[args]{
      content
      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    assert_include(error.message, 'Invalid block command syntax')
  end

  def test_deeply_nested_blocks_success
    content = <<~EOB
      //box[レベル1]{
      レベル1のコンテンツ

      //note[レベル2]{
      レベル2のコンテンツ

      //tip[レベル3]{
      レベル3のコンテンツ

      //list[deep][深いネスト]{
      puts "深いネスト"
      //}

      レベル3の終わり
      //}

      レベル2の終わり
      //}

      レベル1の終わり
      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    assert_nothing_raised do
      ast = compiler.compile_to_ast(chapter)

      # 最上位はboxブロック
      box_node = ast.children[0]
      assert_equal AST::BlockNode, box_node.class
      assert_equal :box, box_node.block_type

      # ネストした構造が正しく構築されることを確認
      note_nodes = box_node.children.select { |child| child.is_a?(AST::MinicolumnNode) && child.minicolumn_type == :note }
      assert_equal 1, note_nodes.size

      note_node = note_nodes.first
      tip_nodes = note_node.children.select { |child| child.is_a?(AST::MinicolumnNode) && child.minicolumn_type == :tip }
      assert_equal 1, tip_nodes.size

      tip_node = tip_nodes.first
      code_nodes = tip_node.children.select { |child| child.is_a?(AST::CodeBlockNode) }
      assert_equal 1, code_nodes.size
      assert_equal 'deep', code_nodes.first.id
    end
  end

  def test_deeply_nested_blocks_unclosed_middle
    content = <<~EOB
      //box[レベル1]{
      レベル1のコンテンツ

      //note[レベル2]{
      レベル2のコンテンツ

      //tip[レベル3]{
      レベル3のコンテンツ
      # //} が欠けている（レベル3未閉）

      //}

      レベル1の終わり
      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    # 深いネストでの未閉ブロックエラーを確認
    assert_include(error.message.downcase, 'unclosed')
  end

  def test_mismatched_block_structure
    content = <<~EOB
      //note[注意]{
      注意書きです。

      //list[example][サンプル]{
      def hello
        puts "world"
      //}

      //box[ボックス]{
      ボックス内容
      # noteの//}を先に閉じようとする
      //}

      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    # この場合は正常に処理される（ネストした構造として扱われる）
    assert_nothing_raised do
      ast = compiler.compile_to_ast(chapter)

      # noteミニコラムの中にlistとboxの両方が含まれる
      note_node = ast.children[0]
      assert_equal AST::MinicolumnNode, note_node.class

      # ネストしたブロックが正しく配置される
      code_blocks = note_node.children.select { |child| child.is_a?(AST::CodeBlockNode) }
      assert_equal 1, code_blocks.size

      box_blocks = note_node.children.select { |child| child.is_a?(AST::BlockNode) && child.block_type == :box }
      assert_equal 1, box_blocks.size
    end
  end

  def test_block_with_empty_content
    content = <<~EOB
      //note[注意]{
      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    assert_nothing_raised do
      ast = compiler.compile_to_ast(chapter)

      note_node = ast.children[0]
      assert_equal AST::MinicolumnNode, note_node.class
      # 空のブロックも正常に処理される
    end
  end

  def test_unexpected_eof_in_nested_block
    content = <<~EOB
      //note[注意]{
      注意書きです。

      //list[example][サンプル]{
      def hello
        puts "world"
    EOB
    # ファイルが途中で終わる

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    error = assert_raise(CompileError) do
      compiler.compile_to_ast(chapter)
    end

    # EOFエラーまたは未閉ブロックエラーのどちらかが発生
    assert(error.message.include?('Unexpected end of file') || error.message.include?('Unclosed block'))
  end

  def test_preprocessor_directive_in_nested_block
    content = <<~EOB
      //note[注意]{
      注意書きです。

      //list[example][サンプル]{
      def hello
      #@# これはプリプロセッサディレクティブ
        puts "world"
      //}

      追加テキスト
      //}
    EOB

    chapter = create_chapter(content)
    compiler = AST::Compiler.new

    assert_nothing_raised do
      ast = compiler.compile_to_ast(chapter)

      # プリプロセッサディレクティブは適切にスキップされる
      note_node = ast.children[0]
      code_blocks = note_node.children.select { |child| child.is_a?(AST::CodeBlockNode) }
      assert_equal 1, code_blocks.size

      # プリプロセッサディレクティブが除外されていることを確認
      code_lines = code_blocks.first.children
      code_content = code_lines.map { |line| line.children.map(&:content).join }.join("\n")
      assert_not_include(code_content, '#@#')
    end
  end
end
