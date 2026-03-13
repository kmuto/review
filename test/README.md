# Re:VIEWプロジェクト テストファイル一覧

このドキュメントは、Re:VIEWプロジェクトのテストファイルの概要を説明します。

## テストファイルのカテゴリー

### AST（抽象構文木）関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_ast_basic.rb` | AST基本ノード（Node、HeadlineNode）の作成と基本機能のテスト |
| `test_ast_inline.rb` | インライン要素（TextNode等）のAST表現のテスト |
| `test_ast_inline_structure.rb` | インライン構造の詳細なASTテスト |
| `test_ast_comprehensive_inline.rb` | インライン要素の包括的なASTテスト |
| `test_ast_embed.rb` | 埋め込み要素のASTテスト |
| `test_ast_lists.rb` | リスト要素のAST表現のテスト |
| `test_ast_comprehensive.rb` | AST機能の包括的なテスト |
| `test_ast_json_serialization.rb` | ASTのJSON形式へのシリアライズ機能のテスト |
| `test_ast_json_verification.rb` | ASTのJSON検証機能のテスト |
| `test_ast_review_generator.rb` | ASTからRe:VIEW形式への逆変換のテスト |
| `test_ast_bidirectional_conversion.rb` | ASTの双方向変換（Re:VIEW↔AST）のテスト |
| `test_ast_analyzer.rb` | AST解析機能のテスト |
| `test_ast_indexer.rb` | AST索引機能のテスト |
| `test_ast_indexer_pure.rb` | AST索引機能の単体テスト |
| `test_ast_structure_debug.rb` | AST構造のデバッグ機能のテスト |
| `test_full_ast_mode.rb` | 完全ASTモードのテスト |

### ビルダー関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_builder.rb` | 基底Builderクラスの基本機能テスト |
| `test_htmlbuilder.rb` | HTML出力ビルダーの機能テスト |
| `test_latexbuilder.rb` | LaTeX出力ビルダーの機能テスト |
| `test_latexbuilder_v2.rb` | LaTeXビルダーのバージョン2機能テスト |
| `test_markdownbuilder.rb` | Markdown出力ビルダーの機能テスト |
| `test_plaintextbuilder.rb` | プレーンテキスト出力ビルダーのテスト |
| `test_idgxmlbuilder.rb` | InDesign XML出力ビルダーのテスト |
| `test_topbuilder.rb` | TOP（テキスト）出力ビルダーのテスト |
| `test_rstbuilder.rb` | reStructuredText出力ビルダーのテスト |
| `test_md2inaobuilder.rb` | Markdown→InDesign形式変換ビルダーのテスト |
| `test_indexbuilder.rb` | 索引ビルダーの機能テスト |
| `test_jsonbuilder.rb` | JSON出力ビルダーのテスト |

### レンダラー関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_html_renderer.rb` | HTMLレンダラーのテスト |
| `test_latex_renderer.rb` | LaTeXレンダラーのテスト |
| `test_html_renderer_builder_comparison.rb` | HTMLレンダラーとビルダーの比較テスト |
| `test_latex_renderer_builder_comparison.rb` | LaTeXレンダラーとビルダーの比較テスト |

### コンパイラ・パーサー関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_compiler.rb` | Re:VIEWソースコードのコンパイラ機能テスト |
| `test_preprocessor.rb` | プリプロセッサ（#@mapfile等）の機能テスト |
| `test_converter.rb` | 形式変換コンバーターのテスト |
| `test_list_parser.rb` | リスト要素のパーサーテスト |
| `test_caption_parser.rb` | キャプションパーサーのテスト |
| `test_caption_node.rb` | キャプションノードのテスト |
| `test_caption_inline_integration.rb` | キャプションとインライン要素の統合テスト |

### 書籍構造関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_book.rb` | 書籍全体の構造と管理機能のテスト |
| `test_book_chapter.rb` | 章（Chapter）クラスの機能テスト |
| `test_book_part.rb` | 部（Part）クラスの機能テスト |
| `test_catalog.rb` | カタログ（章構成）機能のテスト |
| `test_index.rb` | 索引機能のテスト |

### メーカー（生成器）関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_epubmaker.rb` | EPUB生成機能のテスト |
| `test_epub3maker.rb` | EPUB3生成機能のテスト |
| `test_pdfmaker.rb` | PDF生成機能のテスト |
| `test_makerhelper.rb` | メーカー共通ヘルパー機能のテスト |

### コマンドラインツール関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_epubmaker_cmd.rb` | review-epubmakerコマンドのテスト |
| `test_pdfmaker_cmd.rb` | review-pdfmakerコマンドのテスト |
| `test_textmaker_cmd.rb` | review-textmakerコマンドのテスト |
| `test_idgxmlmaker_cmd.rb` | review-idgxmlmakerコマンドのテスト |
| `test_catalog_converter_cmd.rb` | カタログ変換コマンドのテスト |

### ユーティリティ関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_textutils.rb` | テキスト処理ユーティリティのテスト |
| `test_htmlutils.rb` | HTML処理ユーティリティのテスト |
| `test_image_finder.rb` | 画像ファイル検索機能のテスト |
| `test_location.rb` | ソースコード位置情報のテスト |
| `test_lineinput.rb` | 行入力処理のテスト |
| `test_logger.rb` | ログ出力機能のテスト |
| `test_yamlloader.rb` | YAML設定ファイル読み込みのテスト |
| `test_template.rb` | テンプレート処理機能のテスト |
| `test_sec_counter.rb` | セクション番号カウンターのテスト |
| `test_zip_exporter.rb` | ZIP形式エクスポート機能のテスト |

### 設定・国際化関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_configure.rb` | 設定機能のテスト |
| `test_i18n.rb` | 国際化（多言語対応）機能のテスト |
| `test_extentions_hash.rb` | ハッシュ拡張機能のテスト |

### その他の機能テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_review_ext.rb` | review-ext.rb拡張機能のテスト |
| `test_tocprinter.rb` | 目次出力機能のテスト |
| `test_htmltoc.rb` | HTML目次生成機能のテスト |
| `test_webtocprinter.rb` | Web用目次出力機能のテスト |
| `test_reviewheaderlistener.rb` | ヘッダー情報リスナーのテスト |
| `test_update.rb` | 更新機能のテスト |
| `test_img_math.rb` | 数式画像処理のテスト |
| `test_img_graph.rb` | グラフ画像処理のテスト |
| `test_project_integration.rb` | プロジェクト統合テスト |
| `test_dumper.rb` | ダンプ機能のテスト |
| `test_helper.rb` | テストヘルパー機能 |

### ブロック・インライン処理関連テスト

| ファイル名 | 説明 |
|-----------|------|
| `test_block_processor_inline.rb` | ブロック内インライン処理のテスト |
| `test_code_block_debug.rb` | コードブロックのデバッグ機能テスト |
| `test_code_block_inline_processing.rb` | コードブロック内インライン処理のテスト |
| `test_code_block_original_text.rb` | コードブロックの元テキスト保持機能のテスト |
| `test_original_text_integration.rb` | 元テキスト統合機能のテスト |
| `test_new_block_commands.rb` | 新しいブロックコマンドのテスト |
| `test_column_sections.rb` | コラムセクション機能のテスト |
| `test_list_ast_processor.rb` | リストAST処理のテスト |
| `test_nested_list_builder.rb` | ネストしたリストのビルド機能のテスト |

## テストの実行方法

全テストを実行する場合：
```bash
bundle exec rake test
```

特定のテストファイルを実行する場合：
```bash
bundle exec ruby test/test_[ファイル名].rb
```

特定のパターンにマッチするテストを実行する場合：
```bash
bundle exec rake test[pattern]
```

## テストの構成

各テストファイルは基本的に以下の構造になっています：

1. `test/test_helper.rb` を require
2. Test::Unit::TestCase を継承したテストクラスを定義
3. `setup` メソッドで初期化処理
4. `test_` で始まるメソッドで個別のテストケースを定義

## 追加情報

- テストは Ruby の Test::Unit フレームワークを使用
- モックやスタブには適宜 minitest/mock を使用
- テストデータは `test/assets/` ディレクトリに配置
- カバレッジ測定には SimpleCov を使用（`bundle exec rake coverage`）