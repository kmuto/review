# frozen_string_literal: true

require_relative '../test_helper'
require 'review/configure'
require 'review/book'
require 'review/i18n'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/block_processor'
require 'review/logger'

class TestASTDlBlock < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @compiler = ReVIEW::AST::Compiler.new
  end

  def create_chapter(content)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content
    chapter
  end

  def test_dl_with_dt_dd_blocks
    input = <<~REVIEW
      //dl{

      //dt{
      API (Application Programming Interface)
      //}
      //dd{
      アプリケーションプログラミングインターフェースの略称。
      ソフトウェアコンポーネント同士が相互に機能を利用するための規約。

      //list[api-example][API呼び出し例]{
      response = api.get('/users/123')
      user_data = JSON.parse(response.body)
      //}

      詳細は公式ドキュメントを参照してください。
      //}

      //dt{
      REST (Representational State Transfer)
      //}
      //dd{
      RESTfulなWebサービスの設計原則。HTTPプロトコルを使用し、
      リソースをURIで識別します。

      主な特徴：
       * ステートレス通信
       * 統一インターフェース
       * キャッシュ可能
       * 階層的システム

      //table[rest-methods][RESTメソッド一覧]{
      メソッド	用途	冪等性
      ------------
      GET	リソース取得	あり
      POST	リソース作成	なし
      PUT	リソース更新	あり
      DELETE	リソース削除	あり
      //}
      //}

      //dt{
      JSON (JavaScript Object Notation)
      //}
      //dd{
      軽量なデータ交換フォーマット。

      //list[json-sample][JSONサンプル]{
      {
        "name": "John Doe",
        "age": 30,
        "email": "john@example.com"
      }
      //}
      //}

      //}
    REVIEW

    ast = @compiler.compile_to_ast(create_chapter(input.strip))

    # Check that we have a document node
    assert_equal ReVIEW::AST::DocumentNode, ast.class

    # Should contain a definition list node
    list_node = ast.children.first
    assert_equal ReVIEW::AST::ListNode, list_node.class
    assert_equal :dl, list_node.list_type

    # Find dt and dd items
    dt_items = list_node.children.select(&:definition_term?)
    dd_items = list_node.children.select(&:definition_desc?)

    # Should have 3 dt items (API, REST, JSON)
    assert_equal 3, dt_items.size
    # Should have 3 dd items (one for each term)
    assert_equal 3, dd_items.size

    # First dt (API)
    api_dt = dt_items[0]
    assert_equal ReVIEW::AST::ListItemNode, api_dt.class
    assert api_dt.definition_term?

    # First dd (API description)
    api_dd = dd_items[0]
    assert_equal ReVIEW::AST::ListItemNode, api_dd.class
    assert api_dd.definition_desc?

    # Check that API dd has paragraphs and a code block
    assert api_dd.children.size > 1

    # Look for the code block in the API dd
    api_code_block = api_dd.children.find { |child| child.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_not_nil(api_code_block)
    assert_equal 'api-example', api_code_block.id
    assert_equal 'API呼び出し例', api_code_block.caption.to_text

    # Second dd (REST description)
    rest_dd = dd_items[1]
    assert_equal ReVIEW::AST::ListItemNode, rest_dd.class
    assert rest_dd.definition_desc?

    # Look for the table in the REST dd
    rest_table = rest_dd.children.find { |child| child.is_a?(ReVIEW::AST::TableNode) }
    assert_not_nil(rest_table)
    assert_equal 'rest-methods', rest_table.id
    assert_equal 'RESTメソッド一覧', rest_table.caption.to_text

    # Check table has header and body rows
    assert_equal 1, rest_table.header_rows.size
    assert_equal 4, rest_table.body_rows.size

    # Third dd (JSON description)
    json_dd = dd_items[2]
    assert_equal ReVIEW::AST::ListItemNode, json_dd.class
    assert json_dd.definition_desc?

    # Look for the JSON code block
    json_code_block = json_dd.children.find { |child| child.is_a?(ReVIEW::AST::CodeBlockNode) }
    assert_not_nil(json_code_block)
    assert_equal 'json-sample', json_code_block.id
  end

  def test_dl_with_multiple_dd
    input = <<~REVIEW
      //dl{

      //dt{
      HTTP
      //}
      //dd{
      HyperText Transfer Protocolの略称。
      //}
      //dd{
      Webブラウザとサーバー間の通信プロトコル。
      //}
      //dd{
      ステートレスなリクエスト/レスポンス型のプロトコル。
      //}

      //dt{
      HTTPS
      //}
      //dd{
      HTTP over TLS/SSLの略称。暗号化された安全なHTTP通信。
      //}

      //}
    REVIEW

    ast = @compiler.compile_to_ast(create_chapter(input.strip))

    list_node = ast.children.first
    assert_equal :dl, list_node.list_type

    # Find dt and dd items
    dt_items = list_node.children.select(&:definition_term?)
    dd_items = list_node.children.select(&:definition_desc?)

    # Should have 2 dt items (HTTP, HTTPS)
    assert_equal 2, dt_items.size
    # Should have 4 dd items (3 for HTTP, 1 for HTTPS)
    assert_equal 4, dd_items.size

    # Check the first dt (HTTP)
    http_dt = dt_items[0]
    assert http_dt.definition_term?

    # Check that we have 3 consecutive dd items for HTTP
    assert dd_items[0].definition_desc?
    assert dd_items[1].definition_desc?
    assert dd_items[2].definition_desc?

    # Check the second dt (HTTPS)
    https_dt = dt_items[1]
    assert https_dt.definition_term?

    # Check that we have 1 dd item for HTTPS
    assert dd_items[3].definition_desc?
  end

  def test_dl_empty
    input = <<~REVIEW
      //dl{
      //}
    REVIEW

    ast = @compiler.compile_to_ast(create_chapter(input.strip))

    list_node = ast.children.first
    assert_equal :dl, list_node.list_type
    assert_equal 0, list_node.children.size
  end

  def test_dl_cannot_use_simple_text_lines
    # This test documents that simple text lines in //dl blocks
    # are treated as list items without proper term/definition structure
    input = <<~REVIEW
      //dl{
      API
          Application Programming Interface
      REST
          Representational State Transfer
      //}
    REVIEW

    ast = @compiler.compile_to_ast(create_chapter(input.strip))

    list_node = ast.children.first
    assert_equal :dl, list_node.list_type

    # Each line becomes a separate list item (not what we want)
    # This demonstrates why //dt and //dd blocks are needed for definition lists
    # In the current implementation, all lines are treated as items
    assert_equal 4, list_node.children.size

    # All items are simple text items (no proper term/definition structure)
    # When using simple text lines instead of //dt and //dd blocks,
    # empty ListItemNodes are created (without proper content parsing)
    list_node.children.each do |item|
      assert_equal ReVIEW::AST::ListItemNode, item.class
      # Simple text lines in //dl blocks are not properly parsed into content,
      # resulting in empty ListItemNodes. This demonstrates why //dt and //dd
      # blocks are required for proper definition list structure.
      # None of them have dt or dd type
      assert_nil(item.item_type)
    end
  end

  def test_dl_with_nested_content
    input = <<~REVIEW
      //dl{

      //dt{
      ネストしたリスト
      //}
      //dd{
      定義内にさらにリストを含む例：

       * 項目1
       * 項目2
       ** サブ項目2.1
       ** サブ項目2.2

      //note[メモ]{
      ネストしたリストは読みやすさを保ちながら
      複雑な情報を整理できます。
      //}
      //}

      //}
    REVIEW

    ast = @compiler.compile_to_ast(create_chapter(input.strip))

    list_node = ast.children.first
    assert_equal :dl, list_node.list_type

    # Find dt and dd items
    dt_items = list_node.children.select(&:definition_term?)
    dd_items = list_node.children.select(&:definition_desc?)

    # Should have 1 dt and 1 dd
    assert_equal 1, dt_items.size
    assert_equal 1, dd_items.size

    dd_item = dd_items[0]

    # Look for nested list
    ul_node = dd_item.children.find { |child| child.is_a?(ReVIEW::AST::ListNode) && child.list_type == :ul }
    assert_not_nil(ul_node)

    # Look for minicolumn
    note_node = dd_item.children.find { |child| child.is_a?(ReVIEW::AST::MinicolumnNode) }
    assert_not_nil(note_node)
    assert_equal :note, note_node.minicolumn_type
  end
end
