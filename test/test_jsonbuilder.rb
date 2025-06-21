# frozen_string_literal: true

require_relative 'test_helper'
require 'review/jsonbuilder'
require 'review/compiler'
require 'review/book'
require 'review/book/chapter'
require 'json'

class TestJSONBuilder < Test::Unit::TestCase
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

  def test_basic_document_structure
    content = <<~EOB
      = Test Chapter

      This is a test paragraph.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    assert_equal 'document', json_data['type']
    assert json_data.key?('content')
    assert json_data['content'].is_a?(Array)
    assert json_data['content'].size >= 2

    # Check headline
    headline = json_data['content'].find { |item| item['type'] == 'headline' }
    assert_not_nil(headline)
    assert_equal 1, headline['level']
    assert_equal 'Test Chapter', headline['caption']

    # Check paragraph
    paragraph = json_data['content'].find { |item| item['type'] == 'paragraph' }
    assert_not_nil(paragraph)
    assert_equal 'This is a test paragraph.', paragraph['content']
  end

  def test_lists
    content = <<~EOB
      = Lists Test

       * Item 1
       * Item 2
       * Item 3

       1. Numbered item 1
       2. Numbered item 2

       : Term 1
          Definition 1
       : Term 2
          Definition 2
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Check unordered list
    ul = json_data['content'].find { |item| item['type'] == 'unordered_list' }
    assert_not_nil(ul)
    assert_equal 3, ul['items'].size
    assert_equal 'Item 1', ul['items'][0]

    # Check ordered list
    ol = json_data['content'].find { |item| item['type'] == 'ordered_list' }
    assert_not_nil(ol)
    assert_equal 2, ol['items'].size
    assert_equal '1', ol['items'][0]['number']
    assert_equal 'Numbered item 1', ol['items'][0]['content']

    # Check definition list
    dl = json_data['content'].find { |item| item['type'] == 'definition_list' }
    assert_not_nil(dl)
    assert_equal 2, dl['items'].size
    assert_equal 'Term 1', dl['items'][0]['term']
    assert_equal 'Definition 1', dl['items'][0]['definition']
  end

  def test_code_blocks
    content = <<~EOB
      = Code Blocks Test

      //list[sample][Sample Code][ruby]{
      puts "Hello, World!"
      puts "This is Ruby code"
      //}

      //emlist[Example]{
      echo "Shell command"
      ls -la
      //}

      //cmd[Command Example]{
      $ ls -la
      $ pwd
      //}
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Check list (numbered code block)
    code_block = json_data['content'].find { |item| item['type'] == 'code_block' && item['id'] == 'sample' }
    assert_not_nil(code_block)
    assert_equal 'sample', code_block['id']
    assert_equal 'Sample Code', code_block['caption']
    assert_equal 'ruby', code_block['lang']
    assert_equal false, code_block['numbered']
    assert_equal 2, code_block['lines'].size

    # Check emlist
    emlist_block = json_data['content'].find { |item| item['type'] == 'code_block' && item['caption'] == 'Example' }
    assert_not_nil(emlist_block)
    assert_nil(emlist_block['id'])
    assert_equal 'Example', emlist_block['caption']

    # Check cmd
    cmd_block = json_data['content'].find { |item| item['type'] == 'command_block' }
    assert_not_nil(cmd_block)
    assert_equal 'Command Example', cmd_block['caption']
    assert_equal 2, cmd_block['lines'].size
  end

  def test_tables
    content = <<~EOB
      = Tables Test

      //table[sample][Sample Table]{
      Header 1	Header 2	Header 3
      ============
      Cell 1	Cell 2	Cell 3
      Cell 4	Cell 5	Cell 6
      //}

      //emtable[Simple Table]{
      Name	Age
      Alice	25
      Bob	30
      //}
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Check table with headers
    table = json_data['content'].find { |item| item['type'] == 'table' && item['id'] == 'sample' }
    assert_not_nil(table)
    assert_equal 'sample', table['id']
    assert_equal 'Sample Table', table['caption']
    assert_equal 1, table['headers'].size
    assert_equal ['Header 1', 'Header 2', 'Header 3'], table['headers'][0]
    assert_equal 1, table['rows'].size # All cells are in one row array
    # The rows contain all cells as a flat array
    assert table['rows'][0].is_a?(Array)

    # Check emtable (no explicit headers)
    emtable = json_data['content'].find { |item| item['type'] == 'table' && item['caption'] == 'Simple Table' }
    assert_not_nil(emtable)
    assert_nil(emtable['id'])
    assert_equal 'Simple Table', emtable['caption']
    assert_equal [], emtable['headers']
    assert_equal 1, emtable['rows'].size # All rows in one array
  end

  def test_inline_elements
    content = <<~EOB
      = Inline Elements Test

      This paragraph has @<b>{bold} and @<i>{italic} text.

      Code: @<code>{puts "hello"} and typewriter: @<tt>{monospace}.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Find paragraphs with inline elements
    paragraphs = json_data['content'].select { |item| item['type'] == 'paragraph' }
    assert_equal 2, paragraphs.size

    # Check that inline elements are processed (they appear as JSON strings within content)
    first_para = paragraphs[0]['content']
    assert first_para.include?('bold')
    assert first_para.include?('italic')

    second_para = paragraphs[1]['content']
    assert second_para.include?('hello')
    assert second_para.include?('monospace')
  end

  def test_special_blocks
    content = <<~EOB
      = Special Blocks Test

      //quote{
      This is a quote block.
      Multiple lines supported.
      //}

      //embed[html]{
      <div>Raw HTML content</div>
      //}
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Check quote
    quote = json_data['content'].find { |item| item['type'] == 'quote' }
    assert_not_nil(quote)
    assert quote['content'].include?('This is a quote block.')

    # Check embed
    embed = json_data['content'].find { |item| item['type'] == 'embed' }
    assert_not_nil(embed)
    assert_equal 'html', embed['arg']
    assert embed['content'].include?('<div>')
  end

  def test_pure_ast_mode_combination
    content = <<~EOB
      = AST + JSON Test

      This is a test for combining Pure AST Mode with JSONBuilder.

      //list[example][Example Code]{
      puts "Hello, AST!"
      //}
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    # Get both JSON output and AST structure
    json_result = compiler.compile(chapter)
    ast_result = compiler.ast_result

    # Verify JSON output
    json_data = JSON.parse(json_result)
    assert_equal 'document', json_data['type']
    assert json_data['content'].size >= 2

    # Verify AST structure
    assert_not_nil(ast_result)
    assert_equal ReVIEW::AST::DocumentNode, ast_result.class
    assert ast_result.children.any?

    # Both should represent the same content
    headline_json = json_data['content'].find { |item| item['type'] == 'headline' }
    headline_ast = ast_result.children.find { |child| child.is_a?(ReVIEW::AST::HeadlineNode) }

    assert_not_nil(headline_json)
    assert_not_nil(headline_ast)
    # Extract caption text from CaptionNode
    caption_text = if headline_ast.caption.respond_to?(:children) && headline_ast.caption.children.any?
                     headline_ast.caption.children.map do |child|
                       child.respond_to?(:content) ? child.content : child.to_s
                     end.join
                   else
                     headline_ast.caption.to_s
                   end
    assert_equal headline_json['caption'], caption_text
  end

  def test_empty_content
    content = <<~EOB
      = Empty Chapter
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    assert_equal 'document', json_data['type']
    assert json_data['content'].is_a?(Array)
    assert_equal 1, json_data['content'].size # Only headline

    headline = json_data['content'][0]
    assert_equal 'headline', headline['type']
    assert_equal 'Empty Chapter', headline['caption']
  end

  def test_complex_document_structure
    content = <<~EOB
      = 複雑な文書構造のテスト

      複数の段落から構成される複雑な文書構造をテストします。
      この段落には@<b>{太字}と@<i>{斜体}、そして@<code>{コード}が含まれています。

      == セクション2: リストとテーブルの組み合わせ

      以下はシステム要件の一覧です：

       * 機能要件
       * 非機能要件

      //table[requirements][要件一覧]{
      項目	重要度	説明
      =================
      パフォーマンス	高	応答時間1秒以内
      セキュリティ	高	SSL/TLS必須
      可用性	中	99.9%目標
      保守性	中	モジュラー設計
      //}

      === セクション2.1: コードブロックとクォート

      実装例を以下に示します：

      //list[auth][認証処理の実装][ruby]{
      def authenticate(user, password)
        # パスワードのハッシュ化
        hashed = BCrypt::Password.create(password)
        
        # データベースから検索
        stored_user = User.find_by(email: user.email)
        return false unless stored_user
        
        # パスワード照合
        BCrypt::Password.new(stored_user.password_hash) == password
      end
      //}

      //quote{
      セキュリティは最初から考慮すべきものであり、
      後から追加できるものではない。

      — セキュリティエンジニアの格言
      //}

      //texequation[quadratic][二次方程式]{
      ax^2 + bx + c = 0
      //}

      //image[architecture][システムアーキテクチャ図]{
      //}

      == セクション3: 複雑なテキストとインライン要素

      この段落では様々なインライン要素を使用します：
      @<href>{https://example.com,公式サイト}へのリンク、
      @<ruby>{漢字,かんじ}のルビ、
      @<kw>{HTTP,HyperText Transfer Protocol}の用語説明、
      そして@<tt>{monospace}フォントの使用例があります。

      数式の参照: @<eq>{quadratic}、
      図の参照: @<img>{architecture}、
      表の参照: @<table>{requirements}。

      == セクション4: 定義リスト

       : API（Application Programming Interface）
            アプリケーション間の通信を可能にするインターフェース
       : REST（Representational State Transfer）
            Webサービスのアーキテクチャスタイルの一つ
       : JSON（JavaScript Object Notation）
            軽量なデータ交換フォーマット

      最後の段落では、これまでの内容をまとめています。
      複数の@<b>{段落}、@<i>{リスト}、@<code>{テーブル}、
      そして@<tt>{コードブロック}が含まれた複雑な文書構造となっています。
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    begin
      result = compiler.compile(chapter)
      json_data = JSON.parse(result)
    rescue StandardError => e
      puts "Compilation error: #{e.message}"
      puts "Log: #{@log_io.string}" if @log_io.string.length > 0
      raise
    end

    # Verify overall document structure
    assert_equal 'document', json_data['type']
    assert json_data['content'].size >= 10 # Multiple elements

    # Count different element types
    element_counts = json_data['content'].group_by { |item| item['type'] }.transform_values(&:size)

    # Verify we have multiple types
    assert element_counts['headline'] >= 4 # Main title + subsections
    assert element_counts['paragraph'] >= 6 # Multiple paragraphs
    assert element_counts['unordered_list'] >= 1 # At least one list
    assert element_counts['table'] >= 1 # Requirements table
    assert element_counts['code_block'] >= 1 # Code example
    assert element_counts['quote'] >= 1 # Quote block
    assert element_counts['equation'] >= 1 # Math equation
    assert element_counts['image'] >= 1 # Architecture diagram
    assert element_counts['definition_list'] >= 1 # Definition list

    # Verify headline levels
    headlines = json_data['content'].select { |item| item['type'] == 'headline' }
    levels = headlines.map { |h| h['level'] }.uniq.sort
    assert_equal [1, 2, 3], levels # Should have levels 1, 2, and 3

    # Verify complex table structure
    table = json_data['content'].find { |item| item['type'] == 'table' && item['id'] == 'requirements' }
    assert_not_nil(table)
    assert_equal '要件一覧', table['caption']
    assert table['headers'].size >= 1
    assert table['rows'].size >= 1

    # Verify code block with proper attributes
    code_block = json_data['content'].find { |item| item['type'] == 'code_block' && item['id'] == 'auth' }
    assert_not_nil(code_block)
    assert_equal '認証処理の実装', code_block['caption']
    assert_equal 'ruby', code_block['lang']
    assert code_block['lines'].size >= 5 # Multiple lines of code

    # Verify equation structure
    equation = json_data['content'].find { |item| item['type'] == 'equation' && item['id'] == 'quadratic' }
    assert_not_nil(equation)
    assert_equal '二次方程式', equation['caption']
    assert equation['content'].include?('ax^2 + bx + c = 0')

    # Verify image structure
    image = json_data['content'].find { |item| item['type'] == 'image' && item['id'] == 'architecture' }
    assert_not_nil(image)
    assert_equal 'システムアーキテクチャ図', image['caption']

    # Verify definition list structure
    def_list = json_data['content'].find { |item| item['type'] == 'definition_list' }
    assert_not_nil(def_list)
    assert def_list['items'].size >= 3 # API, REST, JSON definitions

    api_item = def_list['items'].find { |item| item['term'].include?('API') }
    assert_not_nil(api_item)
    assert api_item['definition'].include?('インターフェース')
  end

  def test_mixed_japanese_english_content
    content = <<~EOB
      = Mixed Language Content / 混合言語コンテンツ

      This paragraph contains both English and Japanese text.
      この段落には@<b>{English}と@<b>{日本語}の両方が含まれています。

      //list[example][Code Example with Comments][python]{
      # 日本語コメント：ユーザー認証
      def authenticate_user(username, password):
          """
          Authenticate user with username and password
          ユーザー名とパスワードでユーザーを認証する
          """
          # Check if user exists / ユーザーの存在確認
          user = get_user(username)
          if not user:
              return False  # User not found / ユーザーが見つからない
          
          # Verify password / パスワード確認
          return verify_password(password, user.password_hash)
      //}

      Key terms in both languages:
      主要な用語（両言語）:

       : Authentication / 認証
            The process of verifying user identity
            ユーザーのアイデンティティを確認するプロセス
       : Authorization / 認可
            The process of granting access rights
            アクセス権を付与するプロセス
       : Session / セッション
            A temporary interaction between user and system
            ユーザーとシステム間の一時的な対話

      Final paragraph with mixed inline elements:
      @<code>{session_id}は@<kw>{セッション識別子,Session Identifier}として使用され、
      @<href>{https://tools.ietf.org/rfc/rfc6265.txt,RFC 6265}で定義されています。
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Verify mixed language content is preserved
    assert_equal 'document', json_data['type']

    # Check headline with mixed languages
    headline = json_data['content'].find { |item| item['type'] == 'headline' }
    assert_not_nil(headline)
    assert headline['caption'].include?('Mixed Language')
    assert headline['caption'].include?('混合言語')

    # Check paragraphs contain both languages
    paragraphs = json_data['content'].select { |item| item['type'] == 'paragraph' }
    mixed_paragraph = paragraphs.find { |p| p['content'].include?('English') && p['content'].include?('日本語') }
    assert_not_nil(mixed_paragraph)

    # Check code block with mixed language comments
    code_block = json_data['content'].find { |item| item['type'] == 'code_block' }
    assert_not_nil(code_block)
    assert_equal 'python', code_block['lang']
    # Verify both English and Japanese comments are preserved
    code_content = code_block['lines'].join("\n")
    assert code_content.include?('日本語コメント')
    assert code_content.include?('Authenticate user')

    # Check definition list with bilingual terms
    def_list = json_data['content'].find { |item| item['type'] == 'definition_list' }
    assert_not_nil(def_list)
    auth_item = def_list['items'].find { |item| item['term'].include?('Authentication') }
    assert_not_nil(auth_item)
    assert auth_item['term'].include?('認証')
    assert auth_item['definition'].include?('verifying')
    assert auth_item['definition'].include?('確認する')
  end

  def test_large_table_structure
    content = <<~EOB
      = Large Table Test

      //table[performance][Performance Benchmarks]{
      Framework	Language	Requests/sec	Memory(MB)	CPU(%)	Notes
      ===============================================
      Express.js	JavaScript	12500	85	45	Node.js framework
      Django	Python	8900	120	60	Full-featured framework
      Rails	Ruby	7200	150	55	Convention over configuration
      Spring Boot	Java	15000	180	50	Enterprise-grade
      FastAPI	Python	18000	95	40	Modern async framework
      Gin	Go	25000	45	35	Minimalist framework
      Phoenix	Elixir	20000	60	30	Actor model based
      //}

      The table above shows comprehensive performance data across multiple dimensions.
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Find the large table
    table = json_data['content'].find { |item| item['type'] == 'table' && item['id'] == 'performance' }
    assert_not_nil(table)

    # Verify table structure
    assert_equal 'Performance Benchmarks', table['caption']
    assert_equal 1, table['headers'].size # One header row
    assert_equal 6, table['headers'][0].size # Six columns

    # Verify column headers
    expected_headers = ['Framework', 'Language', 'Requests/sec', 'Memory(MB)', 'CPU(%)', 'Notes']
    assert_equal expected_headers, table['headers'][0]

    # Verify we have multiple data rows
    assert table['rows'].size >= 1 # Should have the data rows

    # Check that each row has the correct number of columns
    # Note: rows are structured as nested arrays
    assert table['rows'][0].is_a?(Array), 'Rows should be arrays'
    table['rows'][0].each do |row|
      assert_equal 6, row.size, 'Each row should have 6 columns'
    end
  end

  def test_deeply_nested_lists
    content = <<~EOB
      = Nested List Structure

      Project structure with multiple levels:

       * Backend Development
       * API Layer
       * Database Layer
       * Frontend Development
       * UI Components
       * State Management
       * DevOps & Infrastructure
       * CI/CD Pipeline
       * Monitoring

      Numbered task breakdown:

       1. Planning Phase
       2. Development Phase
       3. Testing Phase
       4. Deployment Phase
    EOB

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder)
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    result = compiler.compile(chapter)
    json_data = JSON.parse(result)

    # Find unordered lists
    ul_lists = json_data['content'].select { |item| item['type'] == 'unordered_list' }
    assert ul_lists.size >= 1 # Should have at least one unordered list

    # Check that we have multiple list items
    first_ul = ul_lists.first
    assert first_ul['items'].size >= 3 # Backend, Frontend, DevOps

    # Find ordered lists
    ol_lists = json_data['content'].select { |item| item['type'] == 'ordered_list' }
    assert ol_lists.size >= 1 # Should have at least one ordered list

    # Check ordered list structure
    first_ol = ol_lists.first
    assert first_ol['items'].size >= 4 # Planning, Development, Testing, Deployment

    # Verify numbered items have proper numbering
    first_ol['items'].each_with_index do |item, index|
      assert_equal (index + 1).to_s, item['number']
    end
  end
end
