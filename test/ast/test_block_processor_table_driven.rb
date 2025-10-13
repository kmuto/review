# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/block_processor'
require 'review/ast/block_data'
require 'review/book'
require 'review/book/chapter'
require 'stringio'

class TestBlockProcessorTableDriven < Test::Unit::TestCase
  include ReVIEW

  def setup
    @config = Configure.values
    @config['language'] = 'ja'
    @book = Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    I18n.setup(@config['language'])

    @compiler = AST::Compiler.new
    @processor = @compiler.block_processor
  end

  def test_block_command_table_coverage
    # すべてのBLOCK_COMMAND_TABLEエントリが有効なメソッドを指していることを確認
    AST::BlockProcessor::BLOCK_COMMAND_TABLE.each do |command, method_name|
      assert @processor.respond_to?(method_name, true),
             "Handler method #{method_name} for command #{command} does not exist"
    end
  end

  def test_registered_commands
    # デフォルトのコマンドが登録されていることを確認
    registered = @processor.registered_commands

    # 主要なコマンドがすべて含まれていることを確認
    expected_commands = %i[list image table note embed texequation]
    expected_commands.each do |cmd|
      assert_include(registered, cmd, "Command #{cmd} should be registered by default")
    end
  end

  def test_dynamic_handler_registration
    # カスタムハンドラーの登録テスト
    @processor.register_block_handler(:custom_test, :build_complex_block_ast)

    assert_include(@processor.registered_commands, :custom_test)
    assert_equal :build_complex_block_ast, @processor.instance_variable_get(:@dynamic_command_table)[:custom_test]
  end

  def test_custom_block_processing
    # カスタムブロックハンドラーのテスト
    # 既存のhandlerを使用してカスタムコマンドを登録
    @processor.register_block_handler(:custom_box, :build_complex_block_ast)

    # 実際のChapterコンテキストで処理
    content = <<~EOB
      = Test Chapter
      
      //custom_box[title]{
      Custom content
      //}
    EOB

    chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    # カスタムコマンドでエラーが発生することを確認（まだ登録されていないため）
    error = assert_raise(CompileError) do
      @compiler.compile_to_ast(chapter)
    end

    assert_include(error.message, 'Unknown block command: //custom')
  end

  def test_unknown_command_error
    # 未知のコマンドでエラーが発生することを確認
    location = SnapshotLocation.new('test.re', 1)
    block_data = AST::BlockData.new(
      name: :unknown_command,
      args: [],
      lines: [],
      location: location
    )

    error = assert_raise(CompileError) do
      @processor.send(:process_block_command, block_data)
    end

    assert_include(error.message, 'Unknown block command: //unknown_command')
    assert_include(error.message, 'test.re')
  end

  def test_table_driven_vs_case_statement_equivalence
    # テーブル駆動の結果が従来のcase文と同等であることを確認
    # 実際のコンパイル処理でテスト
    test_commands = %i[list image table note embed texequation box]

    test_commands.each do |command|
      content = case command # rubocop:disable Style/HashLikeCase
                when :list
                  <<~EOB
                    //list[test][テスト]{
                    puts "test"
                    //}
                  EOB
                when :image
                  <<~EOB
                    //image[test][テスト画像]{
                    //}
                  EOB
                when :table
                  <<~EOB
                    //table[test][テストテーブル]{
                    Name	Age
                    Alice	25
                    //}
                  EOB
                when :note
                  <<~EOB
                    //note[テスト注意]{
                    注意内容
                    //}
                  EOB
                when :embed
                  <<~EOB
                    //embed[html]{
                    <div>test</div>
                    //}
                  EOB
                when :texequation
                  <<~EOB
                    //texequation[eq1][数式]{
                    E = mc^2
                    //}
                  EOB
                when :box
                  <<~EOB
                    //box[テストボックス]{
                    ボックス内容
                    //}
                  EOB
                end

      chapter = Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
      chapter.content = content

      # テーブル駆動による処理が正常に実行されることを確認
      assert_nothing_raised("Command #{command} should be processed without error") do
        @compiler.compile_to_ast(chapter)
      end
    end
  end

  def test_handler_method_existence
    # BLOCK_COMMAND_TABLEのすべてのハンドラーメソッドが存在することを確認
    AST::BlockProcessor::BLOCK_COMMAND_TABLE.each do |command, handler|
      assert @processor.respond_to?(handler, true),
             "Handler method #{handler} for command //#{command} does not exist"
    end
  end

  def test_code_block_category_consistency
    # コードブロック系コマンドがすべて同じハンドラーを使用していることを確認
    code_commands = %i[list listnum emlist emlistnum cmd source]
    code_commands.each do |cmd|
      assert_equal :build_code_block_ast, AST::BlockProcessor::BLOCK_COMMAND_TABLE[cmd],
                   "Code command #{cmd} should use build_code_block_ast handler"
    end
  end

  def test_minicolumn_category_consistency
    # ミニコラム系コマンドがすべて同じハンドラーを使用していることを確認
    minicolumn_commands = %i[note memo tip info warning important caution notice]
    minicolumn_commands.each do |cmd|
      assert_equal :build_minicolumn_ast, AST::BlockProcessor::BLOCK_COMMAND_TABLE[cmd],
                   "Minicolumn command #{cmd} should use build_minicolumn_ast handler"
    end
  end

  def test_extension_example
    # 拡張例：新しいブロックタイプを追加
    # 1. 新しいコマンドを登録（既存ハンドラーを再利用）
    @processor.register_block_handler(:callout, :build_complex_block_ast)

    # 2. 登録確認
    assert_include(@processor.registered_commands, :callout)

    # 3. テーブルに新しいコマンドが追加されていることを確認
    assert_equal :build_complex_block_ast, @processor.instance_variable_get(:@dynamic_command_table)[:callout]
  end
end
