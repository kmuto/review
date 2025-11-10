# Re:VIEW AST / Renderer アーキテクチャ概要

この文書は、Re:VIEW の最新実装（`lib/review/ast` および `lib/review/renderer` 配下のソース、ならびに `test/ast` 配下のテスト）に基づき、AST と Renderer の役割分担と処理フローについて整理したものです。

## パイプライン全体像

1. 各章（`ReVIEW::Book::Chapter`）の本文を `AST::Compiler` が読み取り、`DocumentNode` をルートに持つ AST を構築します（`lib/review/ast/compiler.rb`）。
2. AST 生成後に参照解決 (`ReferenceResolver`) と各種後処理（`TsizeProcessor` / `FirstLineNumProcessor` / `NoindentProcessor` / `OlnumProcessor` / `ListStructureNormalizer` / `ListItemNumberingProcessor` / `AutoIdProcessor`）を適用し、構造とメタ情報を整備します。
3. Renderer は 構築された AST を Visitor パターンで走査し、HTML・LaTeX・IDGXML などのフォーマット固有の出力へ変換します（`lib/review/renderer`）。
4. 既存の `EPUBMaker` / `PDFMaker` / `IDGXMLMaker` などを継承する `AST::Command::EpubMaker` / `AST::Command::PdfMaker` / `AST::Command::IdgxmlMaker` が Compiler と Renderer からなる AST 版パイプラインを作ります。

## `AST::Compiler` の詳細

### 主な責務
- Re:VIEW 記法（`.re`）または Markdown（`.md`）のソースを逐次読み込み、要素ごとに AST ノードを構築する (`compile_to_ast`, `build_ast_from_chapter`)。
  - `.re`ファイル: `AST::Compiler`が直接解析してASTを構築
  - `.md`ファイル: `MarkdownCompiler`がMarkly経由でASTを構築（[Markdownサポート](#markdown-サポート)セクション参照）
- インライン記法は `InlineProcessor`、ブロック系コマンドは `BlockProcessor`、箇条書きは `ListProcessor` に委譲して組み立てる。
- 行番号などの位置情報を保持した `SnapshotLocation` を各ノードに付与し、エラー報告やレンダリング時に利用可能にする。
- 参照解決・後処理を含むパイプラインを統括し、検出したエラーを集約して `CompileError` として通知する。

### 入力走査とノード生成

#### Re:VIEWフォーマット（`.re`ファイル）
- `build_ast_from_chapter` は `LineInput` を用いて 1 行ずつ解析し、見出し・段落・ブロックコマンド・リストなどを判定します（`lib/review/ast/compiler.rb` 内の `case` 分岐）。
- 見出し (`compile_headline_to_ast`) ではレベル・タグ・ラベル・キャプションを解析し、`HeadlineNode` に格納します。
- 段落 (`compile_paragraph_to_ast`) は空行で区切り、インライン要素を `InlineProcessor.parse_inline_elements` に渡して `ParagraphNode` の子として生成します。
- ブロックコマンド (`compile_block_command_to_ast`) は `BlockProcessor` が `BlockNode`・`CodeBlockNode`・`TableNode` など適切なノードを返します。
  - `BlockData`（`lib/review/ast/block_data.rb`）: `Data.define`を使用したイミュータブルなデータ構造で、ブロックコマンドの情報（名前・引数・行・ネストされたブロック・位置情報）をカプセル化し、IO読み取りとブロック処理の責務を分離します。
  - `BlockContext` と `BlockReader`（`lib/review/ast/compiler/`）はブロックコマンドの解析と読み込みを担当します。
- リスト系 (`compile_ul_to_ast` / `compile_ol_to_ast` / `compile_dl_to_ast`) は `ListProcessor` を通じて解析・組み立てが行われます。

#### Markdownフォーマット（`.md`ファイル）
- `MarkdownCompiler`が`Markly.parse`でMarkdownをCommonMark準拠のMarkly ASTに変換します（`lib/review/ast/markdown_compiler.rb`）。
- `MarkdownAdapter`がMarkly ASTを走査し、各要素をRe:VIEW ASTノードに変換します（`lib/review/ast/markdown_adapter.rb`）。
  - 見出し → `HeadlineNode`
  - 段落 → `ParagraphNode`
  - コードブロック → `CodeBlockNode` + `CodeLineNode`
  - リスト → `ListNode` + `ListItemNode`
  - テーブル → `TableNode` + `TableRowNode` + `TableCellNode`
  - インライン要素（太字、イタリック、コード、リンクなど）→ `InlineNode` + `TextNode`
- コラムマーカーは`MarkdownHtmlNode`を用いて検出され、`ColumnNode`に変換されます。
- 変換後のASTは`.re`ファイルと同じ後処理パイプライン（参照解決など）を通ります。

### 参照解決と後処理
- `ReferenceResolver` は AST を Visitor として巡回し、`InlineNode` 配下の `ReferenceNode` を該当要素の情報に差し替えます（`lib/review/ast/reference_resolver.rb`）。解決結果は `ResolvedData` として保持され、Renderer はそれを整形して出力します。
- 後処理パイプラインは次の順序で適用されます（`compile_to_ast` 参照）:
  1. `TsizeProcessor`: `//tsize` 情報を事前に反映。
  2. `FirstLineNumProcessor`: 行番号付きコードブロックの初期値を設定。
  3. `NoindentProcessor` / `OlnumProcessor`: `//noindent`, `//olnum` の命令を段落やリストに属性として付与。
  4. `ListStructureNormalizer`: `//beginchild` / `//endchild` を含むリスト構造を整形し、不要なブロックを除去。
  5. `ListItemNumberingProcessor`: 番号付きリストの `item_number` を確定。
  6. `AutoIdProcessor`: 非表示見出しやコラムに自動 ID・通し番号を付与。

## AST ノード階層と特徴

>  詳細は[ast_node.md](ast_node.md)を参照してください。 このセクションでは、AST/Rendererアーキテクチャを理解するために必要な概要のみを説明します。

### 基底クラス

ASTノードは以下の2つの基底クラスから構成されます：

- `AST::Node`（`lib/review/ast/node.rb`）: すべてのASTノードの抽象基底クラス
  - 子ノードの管理（`add_child()`, `remove_child()` など）
  - Visitorパターンのサポート（`accept(visitor)`, `visit_method_name()`）
  - プレーンテキスト変換（`to_inline_text()`）
  - 属性管理とJSONシリアライゼーション

- `AST::LeafNode`（`lib/review/ast/leaf_node.rb`）: 終端ノードの基底クラス
  - 子ノードを持たない（`add_child()`を呼ぶとエラー）
  - `content`属性を持つ（常に文字列）
  - 継承クラス: `TextNode`, `ImageNode`, `EmbedNode`, `FootnoteNode`, `TexEquationNode`

詳細な設計原則やメソッドの説明は[ast_node.md](ast_node.md)の「基底クラス」セクションを参照してください。

### 主なノードタイプ

ASTは以下のような多様なノードタイプで構成されています：

#### ドキュメント構造
- `DocumentNode`: 章全体のルートノード
- `HeadlineNode`: 見出し（レベル、ラベル、キャプションを保持）
- `ParagraphNode`: 段落
- `ColumnNode`, `MinicolumnNode`: コラム要素

#### リスト
- `ListNode`: リスト全体（`:ul`, `:ol`, `:dl`）
- `ListItemNode`: リスト項目（ネストレベル、番号、定義用語を保持）

詳細は[ast_list_processing.md](ast_list_processing.md)を参照してください。

#### テーブル
- `TableNode`: テーブル全体
- `TableRowNode`: 行（ヘッダー/本文を区別）
- `TableCellNode`: セル

#### コードブロック
- `CodeBlockNode`: コードブロック（言語、キャプション情報）
- `CodeLineNode`: コードブロック内の各行

#### インライン要素
- `InlineNode`: インライン命令（`@<b>`, `@<code>` など）
- `TextNode`: プレーンテキスト
- `ReferenceNode`: 参照（`@<img>`, `@<list>` など、後で解決される）

#### その他
- `ImageNode`: 画像（LeafNode）
- `BlockNode`: 汎用ブロック要素
- `FootnoteNode`: 脚注（LeafNode）
- `EmbedNode`, `TexEquationNode`: 埋め込みコンテンツ（LeafNode）
- `CaptionNode`: キャプション要素

各ノードの詳細な属性、メソッド、使用例については[ast_node.md](ast_node.md)を参照してください。

### シリアライゼーション

すべてのノードは`serialize_to_hash`を実装し、`JSONSerializer`がJSON形式での保存/復元を提供します（`lib/review/ast/json_serializer.rb`）。これによりASTのデバッグ、外部ツールとの連携、AST構造の分析が可能になります。

## インライン・参照処理

- `InlineProcessor`（`lib/review/ast/inline_processor.rb`）は `InlineTokenizer` と協調し、`@<cmd>{...}` / `@<cmd>$...$` / `@<cmd>|...|` を解析して `InlineNode` や `TextNode` を生成します。特殊コマンド（`ruby`, `href`, `kw`, `img`, `list`, `table`, `eq`, `fn` など）は専用メソッドで AST を構築します。
- 参照解決後のデータは Renderer での字幕生成やリンク作成に利用されます。

## リスト処理パイプライン

>  詳細は[ast_list_processing.md](ast_list_processing.md)を参照してください。 このセクションでは、アーキテクチャ理解に必要な概要のみを説明します。

リスト処理は以下のコンポーネントで構成されています：

### 主要コンポーネント

- ListParser: Re:VIEW記法のリストを解析し、`ListItemData`構造体を生成（`lib/review/ast/list_parser.rb`）
- NestedListAssembler: `ListItemData`からネストされたAST構造（`ListNode`/`ListItemNode`）を構築
- ListProcessor: パーサーとアセンブラーを統括し、コンパイラーへの統一的なインターフェースを提供（`lib/review/ast/list_processor.rb`）

### 後処理

- ListStructureNormalizer: `//beginchild`/`//endchild`の正規化と連続リストの統合（`lib/review/ast/compiler/list_structure_normalizer.rb`）
- ListItemNumberingProcessor: 番号付きリストの各項目に`item_number`を付与（`lib/review/ast/compiler/list_item_numbering_processor.rb`）

詳細な処理フロー、データ構造、設計原則については[ast_list_processing.md](ast_list_processing.md)を参照してください。

## AST::Visitor と Indexer

- `AST::Visitor`（`lib/review/ast/visitor.rb`）は AST を走査するための基底クラスです。
  - 動的ディスパッチ: 各ノードの `visit_method_name()` メソッドが適切な訪問メソッド名（`:visit_headline`, `:visit_paragraph` など）を返し、Visitorの対応するメソッドを呼び出します。
  - 主要メソッド: `visit(node)`, `visit_all(nodes)`, `extract_text(node)` (private), `process_inline_content(node)` (private)
  - 継承クラス: `Renderer::Base`, `ReferenceResolver`, `Indexer` などがこれを継承し、AST の走査と処理を実現しています。
- `AST::Indexer`（`lib/review/ast/indexer.rb`）は `Visitor` を継承し、AST 走査中に図表・リスト・コードブロック・数式などのインデックスを構築します。参照解決や連番付与に利用され、Renderer は AST を走査する際に Indexer を通じてインデックス情報を取得します。

## Renderer 層

- `Renderer::Base`（`lib/review/renderer/base.rb`）は `AST::Visitor` を継承し、`render`・`render_children`・`render_inline_element` などの基盤処理を提供します。各フォーマット固有のクラスは `visit_*` メソッドをオーバーライドします。
- `RenderingContext`（`lib/review/renderer/rendering_context.rb`）は主に HTML / LaTeX / IDGXML 系レンダラーでレンダリング中の状態（表・キャプション・定義リスト内など）とフットノートの収集を管理し、`footnotetext` への切り替えや入れ子状況の判定を支援します。
- フォーマット別 Renderer:
  - `HtmlRenderer` は HTMLBuilder と互換の出力を生成し、見出しアンカー・リスト整形・脚注処理を再現します（`lib/review/renderer/html_renderer.rb`）。`InlineElementHandler` と `InlineContext`（`lib/review/renderer/html/`）を用いてインライン要素の文脈依存処理を行います。
  - `LatexRenderer` は LaTeXBuilder の挙動（セクションカウンタ・TOC・環境制御・脚注）を再現しつつ `RenderingContext` で扱いを整理しています（`lib/review/renderer/latex_renderer.rb`）。`InlineElementHandler` と `InlineContext`（`lib/review/renderer/latex/`）を用いてインライン要素の文脈依存処理を行います。
  - `IdgxmlRenderer`, `MarkdownRenderer`, `PlaintextRenderer` も同様に `Renderer::Base` を継承し、AST からの直接出力を実現します。
  - `TopRenderer` はテキストベースの原稿フォーマットに変換し、校正記号を付与します（`lib/review/renderer/top_renderer.rb`）。
- `renderer/rendering_context.rb` とそれを利用するレンダラー（HTML / LaTeX / IDGXML）は `FootnoteCollector` を用いて脚注のバッチ処理を行い、Builder 時代の複雑な状態管理を置き換えています。

## Markdown サポート

>  詳細は[ast_markdown.md](ast_markdown.md)を参照してください。 このセクションでは、アーキテクチャ理解に必要な概要のみを説明します。

Re:VIEWはGitHub Flavored Markdown（GFM）をサポートしており、`.md`ファイルをRe:VIEW ASTに変換できます。

### アーキテクチャ

Markdownサポートは以下の3つの主要コンポーネントで構成されています：

- MarkdownCompiler（`lib/review/ast/markdown_compiler.rb`）: Markdownドキュメント全体をRe:VIEW ASTにコンパイルする統括クラス。Marklyパーサーを初期化し、GFM拡張機能（strikethrough, table, autolink, tagfilter）を有効化します。
- MarkdownAdapter（`lib/review/ast/markdown_adapter.rb`）: Markly AST（CommonMark準拠）をRe:VIEW ASTに変換するアダプター層。各Markdown要素を対応するRe:VIEW ASTノードに変換し、コラムスタック・リストスタック・テーブルスタックを管理します。
- MarkdownHtmlNode（`lib/review/ast/markdown_html_node.rb`）: Markdown内のHTML要素を解析し、特別な意味を持つHTMLコメント（コラムマーカーなど）を識別するための補助ノード。最終的なASTには含まれず、変換処理中にのみ使用されます。

### 変換処理の流れ

```
Markdown文書 → Markly.parse → Markly AST
                                    ↓
                          MarkdownAdapter.convert
                                    ↓
                             Re:VIEW AST
                                    ↓
                          参照解決・後処理
                                    ↓
                             Renderer群
```

### サポート機能

- GFM拡張: 取り消し線、テーブル、オートリンク、タグフィルタリング
- Re:VIEW独自拡張:
  - コラム構文（HTMLコメント: `<!-- column: Title -->` / `<!-- /column -->`）
  - コラム構文（見出し: `### [column] Title` / `### [/column]`）
  - 自動コラムクローズ（見出しレベルに基づく）
  - スタンドアローン画像の検出（段落内の単独画像をブロックレベルの`ImageNode`に変換）

### 制限事項

Markdownでは以下のRe:VIEW固有機能はサポートされていません：
- `//list`（キャプション付きコードブロック）→ 通常のコードブロックとして扱われます
- `//table`（キャプション付き表）→ GFMテーブルは使用できますが、キャプションやラベルは付けられません
- `//footnote`（脚注）
- 一部のインライン命令（`@<kw>`, `@<bou>` など）

詳細は[ast_markdown.md](ast_markdown.md)を参照してください。

## 既存ツールとの統合

- EPUB/PDF/IDGXML などの Maker クラス（`AST::Command::EpubMaker`, `AST::Command::PdfMaker`, `AST::Command::IdgxmlMaker`）は、それぞれ内部に `RendererConverterAdapter` クラスを定義して Renderer を従来の Converter インターフェースに適合させています（`lib/review/ast/command/epub_maker.rb`, `pdf_maker.rb`, `idgxml_maker.rb`）。各 Adapter は章単位で対応する Renderer（`HtmlRenderer`, `LatexRenderer`, `IdgxmlRenderer`）を生成し、出力をそのまま組版パイプラインへ渡します。
- `lib/review/ast/command/compile.rb` は `review-ast-compile` CLI を提供し、`--target` で指定したフォーマットに対して AST→Renderer パイプラインを直接実行します。`--check` モードでは AST 生成と検証のみを行います。

## JSON / 開発支援ツール

- `JSONSerializer` と `AST::Dumper`（`lib/review/ast/dumper.rb`）は AST を JSON へシリアライズし、デバッグや外部ツールとの連携に利用できます。`Options` により位置情報や簡易モードの有無を制御可能です。
- `AST::ReviewGenerator`（`lib/review/ast/review_generator.rb`）は AST から Re:VIEW 記法を再生成し、双方向変換や差分検証に利用されます。
- `lib/review/ast/diff/html.rb` / `idgxml.rb` / `latex.rb` は Builder と Renderer の出力差異をハッシュ比較し、`test/ast/test_html_renderer_builder_comparison.rb` などで利用されています。

## テストによる保証

- `test/ast/test_ast_comprehensive.rb` / `test_ast_complex_integration.rb` は章全体を AST に変換し、ノード構造とレンダリング結果を検証します。
- `test/ast/test_html_renderer_inline_elements.rb` や `test_html_renderer_join_lines_by_lang.rb` はインライン要素・改行処理など HTML 特有の仕様を確認しています。
- `test/ast/test_list_structure_normalizer.rb`, `test_list_processor.rb` は複雑なリストや `//beginchild` の正規化を網羅します。
- `test/ast/test_ast_comprehensive_inline.rb` は AST→Renderer の往復で特殊なインライン命令が崩れないことを保証します。
- `test/ast/test_markdown_adapter.rb`, `test_markdown_compiler.rb` はMarkdownのAST変換が正しく動作することを検証します。

これらの実装とテストにより、AST を中心とした新しいパイプラインと Renderer 群は従来 Builder と互換の出力を維持しつつ、構造化されたデータモデルとユーティリティを提供しています。

## 関連ドキュメント

Re:VIEWのAST/Rendererアーキテクチャについてさらに学ぶには、以下のドキュメントを参照してください：

| ドキュメント | 説明 |
|------------|------|
| [ast.md](ast.md) | 入門ドキュメント: AST/Rendererの概要と基本的な使い方。最初に読むべきドキュメント。 |
| [ast_node.md](ast_node.md) | ノード詳細: 各ASTノードの詳細な仕様、属性、メソッド、使用例。 |
| [ast_list_processing.md](ast_list_processing.md) | リスト処理: リスト解析・組み立てパイプラインの詳細な説明。 |
| [ast_markdown.md](ast_markdown.md) | Markdownサポート: GitHub Flavored Markdownのサポート機能と使用方法。 |
| [ast_architecture.md](ast_architecture.md) | 本ドキュメント: AST/Rendererアーキテクチャ全体の概要と設計。 |

### 推奨される学習パス

1. 初心者: [ast.md](ast.md) → [ast_node.md](ast_node.md) の基本セクション
2. 中級者: [ast_architecture.md](ast_architecture.md) → [ast_list_processing.md](ast_list_processing.md)
3. Markdown利用者: [ast_markdown.md](ast_markdown.md)
4. 上級者/開発者: 全ドキュメント + ソースコードとテスト
