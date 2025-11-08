# Re:VIEW AST::Node 概要

## 概要

Re:VIEWのAST（Abstract Syntax Tree）は、Re:VIEW形式のテキストを構造化したノードツリーで、様々な出力形式に変換できます。

## 基本設計パターン

1. Visitorパターン: ASTノードの処理にVisitorパターンを使用
2. コンポジットパターン: 親子関係を持つノード構造
3. ファクトリーパターン: CaptionNodeなどの作成
4. シリアライゼーション: JSON形式でのAST保存・復元

## 基底クラス: `AST::Node`

### 主要属性
- `location`: ソースファイル内の位置情報（ファイル名、行番号）
- `parent`: 親ノード（Nodeインスタンス）
- `children`: 子ノードの配列
- `type`: ノードタイプ（文字列）
- `id`: ID（該当する場合）
- `content`: コンテンツ（該当する場合）
- `original_text`: 元のテキスト

### 主要メソッド
- `add_child(child)`, `remove_child(child)`, `replace_child(old_child, new_child)`, `insert_child(idx, *nodes)`: 子ノードの管理
- `leaf_node?()`: リーフノードかどうかを判定
- `reference_node?()`: 参照ノードかどうかを判定
- `id?()`: IDを持つかどうかを判定
- `add_attribute(key, value)`, `attribute?(key)`: 属性の管理
- `visit_method_name()`: Visitorパターンで使用するメソッド名をシンボルで返す
- `to_inline_text()`: マークアップを除いたテキスト表現を返す（ブランチノードでは例外を発生、サブクラスでオーバーライド）
- `to_h`, `to_json`: 基本的なJSON形式のシリアライゼーション
- `serialize_to_hash(options)`: 拡張されたシリアライゼーション

### 設計原則
- ブランチノード: `LeafNode`を継承していないノードクラス全般。子ノードを持つことができる（`ParagraphNode`, `InlineNode`など）
- リーフノード: `LeafNode`を継承し、子ノードを持つことができない（`TextNode`, `ImageNode`など）
- `LeafNode`は`content`属性を持つが、サブクラスが独自の属性を定義可能
- 同じノードで`content`と`children`を混在させない
    - リーフノードも`children`を持つが、必ず空配列を返す(`nil`にはならない)

## 基底クラス: `AST::LeafNode`

### 概要
- 親クラス: Node
- 用途: 子ノードを持たない終端ノードの基底クラス
- 特徴:
  - `content`属性を持つ（常に文字列、デフォルトは空文字列）
  - 子ノードを追加しようとするとエラーを発生
  - `leaf_node?`メソッドが`true`を返す

### 主要メソッド
- `leaf_node?()`: 常に`true`を返す
- `children`: 常に空配列を返す
- `add_child(child)`: エラーを発生（子を持てない）
- `to_inline_text()`: `content`を返す

### LeafNodeを継承するクラス
- `TextNode`: プレーンテキスト（およびそのサブクラス`ReferenceNode`）
- `ImageNode`: 画像（ただし`content`の代わりに`id`, `caption_node`, `metric`を持つ）
- `TexEquationNode`: LaTeX数式
- `EmbedNode`: 埋め込みコンテンツ
- `FootnoteNode`: 脚注定義

## ノードクラス階層図

```
AST::Node (基底クラス)
├── [ブランチノード] - 子ノードを持つことができる
│   ├── DocumentNode                    # ドキュメントルート
│   ├── HeadlineNode                    # 見出し（=, ==, ===）
│   ├── ParagraphNode                   # 段落テキスト
│   ├── InlineNode                      # インライン要素（@<b>{}, @<code>{}等）
│   ├── CaptionNode                     # キャプション（テキスト+インライン要素）
│   ├── ListNode                        # リスト（ul, ol, dl）
│   │   └── ListItemNode               # リストアイテム
│   ├── TableNode                       # テーブル
│   │   ├── TableRowNode               # テーブル行
│   │   └── TableCellNode              # テーブルセル
│   ├── CodeBlockNode                   # コードブロック
│   │   └── CodeLineNode               # コード行
│   ├── BlockNode                       # 汎用ブロック（//quote, //read等）
│   ├── ColumnNode                      # コラム（====[column]{id}）
│   └── MinicolumnNode                  # ミニコラム（//note, //memo等）
│
└── LeafNode (リーフノードの基底クラス) - 子ノードを持てない
    ├── TextNode                        # プレーンテキスト
    │   └── ReferenceNode              # 参照情報を持つテキストノード
    ├── ImageNode                       # 画像（//image, //indepimage等）
    ├── FootnoteNode                    # 脚注定義（//footnote）
    ├── TexEquationNode                 # LaTeX数式ブロック（//texequation）
    └── EmbedNode                       # 埋め込みコンテンツ（//embed, //raw）
```

### ノードの分類

#### 構造ノード（コンテナ）
- `DocumentNode`, `HeadlineNode`, `ParagraphNode`, `ListNode`, `TableNode`, `CodeBlockNode`, `BlockNode`, `ColumnNode`, `MinicolumnNode`

#### コンテンツノード（リーフ）
- `TextNode`, `ReferenceNode`, `ImageNode`, `FootnoteNode`, `TexEquationNode`, `EmbedNode`

#### 特殊ノード
- `InlineNode` (テキストを含むがインライン要素)
- `CaptionNode` (テキストとインライン要素の混合)
- `ReferenceNode` (TextNodeのサブクラス、参照情報を保持)
- `ListItemNode`, `TableRowNode`, `TableCellNode`, `CodeLineNode` (特定の親ノード専用)

## ノードクラス詳細

### 1. ドキュメント構造ノード

#### `DocumentNode`

- 親クラス: Node
- 属性: 
  - `title`: ドキュメントタイトル
  - `chapter`: 関連するチャプター
- 用途: ASTのルートノード、ドキュメント全体を表現
- 例: 一つのチャプターファイル全体
- 特徴: 通常はHeadlineNode、ParagraphNode、BlockNodeなどを子として持つ

#### `HeadlineNode`

- 親クラス: Node
- 属性:
  - `level`: 見出しレベル（1-6）
  - `label`: ラベル（オプション）
  - `caption_node`: キャプション（CaptionNodeインスタンス）
- 用途: `=`, `==`, `===` 形式の見出し
- 例:
  - `= Chapter Title` → level=1, caption_node=CaptionNode
  - `=={label} Section Title` → level=2, label="label", caption_node=CaptionNode
- メソッド: `to_s`: デバッグ用の文字列表現

#### `ParagraphNode`

- 親クラス: Node
- 用途: 通常の段落テキスト
- 特徴: 子ノードとしてTextNodeやInlineNodeを含む
- 例: 通常のテキスト段落、リスト内のテキスト

### 2. テキストコンテンツノード

#### `TextNode`

- 親クラス: Node
- 属性:
  - `content`: テキスト内容（文字列）
- 用途: プレーンテキストを表現
- 特徴: リーフノード（子ノードを持たない）
- 例: 段落内の文字列、インライン要素内の文字列

#### `ReferenceNode`

- 親クラス: TextNode
- 属性:
  - `content`: 表示テキスト（継承）
  - `ref_id`: 参照ID（主要な参照先）
  - `context_id`: コンテキストID（章ID等、オプション）
  - `resolved`: 参照が解決済みかどうか
  - `resolved_data`: 構造化された解決済みデータ（ResolvedData）
- 用途: 参照系インライン要素（`@<img>{}`, `@<table>{}`, `@<fn>{}`など）の子ノードとして使用
- 特徴:
  - TextNodeのサブクラスで、参照情報を保持
  - イミュータブル設計（参照解決時には新しいインスタンスを作成）
  - 未解決時は参照IDを表示、解決後は適切な参照テキストを生成
- 主要メソッド:
  - `resolved?()`: 参照が解決済みかどうかを判定
  - `with_resolved_data(data)`: 解決済みの新しいインスタンスを返す
- 例: `@<img>{sample-image}` → ReferenceNode(ref_id: "sample-image")

#### `InlineNode`

- 親クラス: Node
- 属性: 
  - `inline_type`: インライン要素タイプ（文字列）
  - `args`: 引数配列
- 用途: インライン要素（`@<b>{}`, `@<code>{}` など）
- 例: 
  - `@<b>{太字}` → inline_type="b", args=["太字"]
  - `@<href>{https://example.com,リンク}` → inline_type="href", args=["https://example.com", "リンク"]
- 特徴: 子ノードとしてTextNodeを含むことが多い

### 3. コードブロックノード

#### `CodeBlockNode`

- 親クラス: Node
- 属性:
  - `lang`: プログラミング言語（オプション）
  - `caption_node`: キャプション（CaptionNodeインスタンス）
  - `line_numbers`: 行番号表示フラグ
  - `code_type`: コードブロックタイプ（`:list`, `:emlist`, `:listnum` など）
  - `original_text`: 元のコードテキスト
- 用途: `//list`, `//emlist`, `//listnum` などのコードブロック
- 特徴: `CodeLineNode`の子ノードを持つ
- メソッド:
  - `original_lines()`: 元のテキスト行配列
  - `processed_lines()`: 処理済みテキスト行配列

#### `CodeLineNode`

- 親クラス: Node
- 属性: 
  - `line_number`: 行番号（オプション）
  - `original_text`: 元のテキスト
- 用途: コードブロック内の各行
- 特徴: インライン要素も含むことができる（Re:VIEW記法が使用可能）
- 例: コード内の`@<b>{強調}`のような記法

### 4. リストノード

#### `ListNode`

- 親クラス: Node
- 属性: 
  - `list_type`: リストタイプ（`:ul`（箇条書き）, `:ol`（番号付き）, `:dl`（定義リスト））
  - `olnum_start`: 番号付きリストの開始番号（オプション）
- 用途: 箇条書きリスト（`*`, `1.`, `: 定義`形式）
- 子ノード: `ListItemNode`の配列

#### `ListItemNode`

- 親クラス: Node
- 属性: 
  - `level`: ネストレベル（1以上）
  - `number`: 番号付きリストの番号（オプション）
  - `item_type`: アイテムタイプ（`:ul_item`, `:ol_item`, `:dt`, `:dd`）
- 用途: リストアイテム
- 特徴: ネストしたリストや段落を子として持つことができる

### 5. テーブルノード

#### `TableNode`

- 親クラス: Node
- 属性:
  - `caption_node`: キャプション（CaptionNodeインスタンス）
  - `table_type`: テーブルタイプ（`:table`, `:emtable`, `:imgtable`）
  - `metric`: メトリック情報（幅設定など）
- 特別な構造:
  - `header_rows`: ヘッダー行の配列
  - `body_rows`: ボディ行の配列
- 用途: `//table`コマンドのテーブル
- メソッド: ヘッダーとボディの行を分けて管理

#### `TableRowNode`

- 親クラス: Node
- 属性: 
  - `row_type`: 行タイプ（`:header`, `:body`）
- 用途: テーブルの行
- 子ノード: `TableCellNode`の配列

#### `TableCellNode`

- 親クラス: Node
- 属性: 
  - `cell_type`: セルタイプ（`:th`（ヘッダー）または `:td`（通常セル））
  - `colspan`, `rowspan`: セル結合情報（オプション）
- 用途: テーブルのセル
- 特徴: TextNodeやInlineNodeを子として持つ

### 6. メディアノード

#### `ImageNode`

- 親クラス: Node
- 属性:
  - `caption_node`: キャプション（CaptionNodeインスタンス）
  - `metric`: メトリック情報（サイズ、スケール等）
  - `image_type`: 画像タイプ（`:image`, `:indepimage`, `:numberlessimage`）
- 用途: `//image`, `//indepimage`コマンドの画像
- 特徴: リーフノード
- 例: `//image[sample][キャプション][scale=0.8]`

### 7. 特殊ブロックノード

#### `BlockNode`

- 親クラス: Node
- 属性:
  - `block_type`: ブロックタイプ（`:quote`, `:read`, `:lead` など）
  - `args`: 引数配列
  - `caption_node`: キャプション（CaptionNodeインスタンス、オプション）
- 用途: 汎用ブロックコンテナ（引用、読み込み等）
- 例:
  - `//quote{ ... }` → block_type=":quote"
  - `//read[ファイル名]` → block_type=":read", args=["ファイル名"]

#### `ColumnNode`

- 親クラス: Node
- 属性:
  - `level`: コラムレベル（通常9）
  - `label`: ラベル（ID）— インデックス対応完了
  - `caption_node`: キャプション（CaptionNodeインスタンス）
  - `column_type`: コラムタイプ（`:column`）
- 用途: `//column`コマンドのコラム、`====[column]{id} タイトル`形式
- 特徴:
  - 見出しのような扱いだが、独立したコンテンツブロック
  - `label`属性でIDを指定可能、`@<column>{chapter|id}`で参照
  - AST::Indexerでインデックス処理される

#### `MinicolumnNode`

- 親クラス: Node
- 属性:
  - `minicolumn_type`: ミニコラムタイプ（`:note`, `:memo`, `:tip`, `:info`, `:warning`, `:important`, `:caution` など）
  - `caption_node`: キャプション（CaptionNodeインスタンス）
- 用途: `//note`, `//memo`, `//tip`などのミニコラム
- 特徴: 装飾的なボックス表示される小さなコンテンツブロック

#### `EmbedNode`

- 親クラス: Node
- 属性: 
  - `lines`: 埋め込みコンテンツの行配列
  - `arg`: 引数（単一行の場合）
  - `embed_type`: 埋め込みタイプ（`:block`または`:inline`）
- 用途: 埋め込みコンテンツ（`//embed`, `//raw`など）
- 特徴: リーフノード、生のコンテンツをそのまま保持

#### `FootnoteNode`

- 親クラス: Node
- 属性: 
  - `id`: 脚注ID
  - `content`: 脚注内容
  - `footnote_type`: 脚注タイプ（`:footnote`または`:endnote`）
- 用途: `//footnote`コマンドの脚注定義
- 特徴: 
  - ドキュメント内の脚注定義部分
  - AST::FootnoteIndexで統合処理（インライン参照とブロック定義）
  - 重複ID問題と内容表示の改善完了

#### `TexEquationNode`

- 親クラス: Node
- 属性:
  - `label`: 数式ID（オプション）
  - `caption_node`: キャプション（CaptionNodeインスタンス）
  - `code`: LaTeX数式コード
- 用途: `//texequation`コマンドのLaTeX数式ブロック
- 特徴:
  - ID付き数式への参照機能対応
  - LaTeX数式コードをそのまま保持
  - 数式インデックスで管理される

### 8. 特殊ノード

#### `CaptionNode`

- 親クラス: Node
- 特殊機能:
  - ファクトリーメソッド `CaptionNode.parse(caption_text, location)`
  - テキストとインライン要素の解析
- 用途: キャプションでインライン要素とテキストを含む
- メソッド:
  - `to_inline_text()`: マークアップを除いたプレーンテキスト変換（子ノードを再帰的に処理）
  - `contains_inline?()`: インライン要素を含むかチェック
  - `empty?()`: 空かどうかのチェック
- 例: `this is @<b>{bold} caption` → TextNode + InlineNode + TextNode
- 設計方針:
  - 常に構造化されたノード（children配列）として扱われる
  - JSON出力では文字列としての`caption`フィールドを出力しない
  - キャプションは構造を持つべきという設計原則を徹底

## 処理システム

### Visitorパターン (`Visitor`)

- 目的: ノードごとの処理メソッドを動的に決定
- メソッド命名規則: `visit_#{node_type}`（例：`visit_headline`, `visit_paragraph`）
- メソッド名の決定: 各ノードの`visit_method_name()`メソッドが適切なシンボルを返す
- 主要メソッド:
  - `visit(node)`: ノードの`visit_method_name()`を呼び出して適切なvisitメソッドを決定し実行
  - `visit_all(nodes)`: 複数のノードを訪問して結果の配列を返す
- 例: `HeadlineNode`に対して`visit_headline(node)`が呼ばれる
- 実装の詳細:
  - ノードの`visit_method_name()`がCamelCaseからsnake_caseへの変換を行う
  - クラス名から`Node`サフィックスを除去して`visit_`プレフィックスを追加

### インデックス系システム (`Indexer`)

- 目的: ASTノードから各種インデックスを生成
- 対応要素:
  - HeadlineNode: 見出しインデックス
  - ColumnNode: コラムインデックス
  - ImageNode, TableNode, ListNode: 各種図表インデックス

### 脚注インデックス (`FootnoteIndex`)

- 目的: AST専用の脚注管理システム
- 特徴:
  - インライン参照とブロック定義の統合処理
  - 重複ID問題の解決
  - 従来のBook::FootnoteIndexとの互換性保持

### 6. データ構造 (`BlockData`)

#### `BlockData`


- 定義: `Data.define`を使用したイミュータブルなデータ構造
- 目的: ブロックコマンドの情報をカプセル化し、IO読み取りとブロック処理の責務を分離
- パラメータ:
  - `name` [Symbol]: ブロックコマンド名（例：`:list`, `:note`, `:table`）
  - `args` [Array<String>]: コマンドライン引数（デフォルト: `[]`）
  - `lines` [Array<String>]: ブロック内のコンテンツ行（デフォルト: `[]`）
  - `nested_blocks` [Array<BlockData>]: ネストされたブロックコマンド（デフォルト: `[]`）
  - `location` [SnapshotLocation]: エラー報告用のソース位置情報
- 主要メソッド:
  - `nested_blocks?()`: ネストされたブロックを持つかどうかを判定
  - `line_count()`: 行数を返す
  - `content?()`: コンテンツ行を持つかどうかを判定
  - `arg(index)`: 指定されたインデックスの引数を安全に取得
- 使用例:
  - Compilerがブロックを読み取り、BlockDataインスタンスを作成
  - BlockProcessorがBlockDataを受け取り、適切なASTノードを生成
- 特徴: イミュータブルな設計により、データの一貫性と予測可能性を保証

### 7. リスト処理アーキテクチャ

リスト処理は複数のコンポーネントが協調して動作します。詳細は [doc/ast_list_processing.md](./ast_list_processing.md) を参照してください。

#### `ListParser`

- 目的: Re:VIEW記法のリストを解析
- 責務:
  - 生テキスト行からリスト項目を抽出
  - ネストレベルの判定
  - 継続行の収集
- データ構造:
  - `ListItemData`: `Struct.new`で定義されたリスト項目データ
    - `type`: 項目タイプ（`:ul_item`, `:ol_item`, `:dt`, `:dd`）
    - `level`: ネストレベル（デフォルト: 1）
    - `content`: 項目内容
    - `continuation_lines`: 継続行の配列（デフォルト: `[]`）
    - `metadata`: メタデータハッシュ（デフォルト: `{}`）
    - `with_adjusted_level(new_level)`: レベルを調整した新しいインスタンスを返す

#### `NestedListAssembler`

- 目的: 解析されたデータから実際のAST構造を組み立て
- 対応機能:
  - 6レベルまでの深いネスト対応
  - 非対称・不規則パターンの処理
  - リストタイプの混在対応（番号付き・箇条書き・定義リスト）
- 主要メソッド:
  - `build_nested_structure(items, list_type)`: ネスト構造の構築
  - `build_unordered_list(items)`: 箇条書きリストの構築
  - `build_ordered_list(items)`: 番号付きリストの構築

#### `ListProcessor`

- 目的: リスト処理全体の調整
- 責務:
  - ListParserとNestedListAssemblerの協調
  - コンパイラーへの統一的なインターフェース提供
- 内部構成:
  - `@parser`: ListParserインスタンス
  - `@nested_list_assembler`: NestedListAssemblerインスタンス
- 公開アクセサー:
  - `parser`: ListParserへのアクセス（読み取り専用）
  - `nested_list_assembler`: NestedListAssemblerへのアクセス（読み取り専用）
- 主要メソッド:
  - `process_unordered_list(f)`: 箇条書きリスト処理
  - `process_ordered_list(f)`: 番号付きリスト処理
  - `process_definition_list(f)`: 定義リスト処理
  - `parse_list_items(f, list_type)`: リスト項目の解析（テスト用）
  - `build_list_from_items(items, list_type)`: 項目からリストノードを構築

#### `ListStructureNormalizer`

- 目的: リスト構造の正規化と整合性保証
- 責務:
  - ネストされたリスト構造の整合性チェック
  - 不正なネスト構造の修正
  - 空のリストノードの除去

#### `ListItemNumberingProcessor`

- 目的: 番号付きリストの番号管理
- 責務:
  - 連番の割り当て
  - ネストレベルに応じた番号の管理
  - カスタム開始番号のサポート

### 8. インライン要素レンダラー (`InlineElementRenderer`)

- 目的: LaTeXレンダラーからインライン要素処理を分離
- 特徴:
  - 保守性とテスタビリティの向上
  - メソッド名の統一（`render_inline_xxx`形式）
  - コラム参照機能の完全実装

### 9. JSON シリアライゼーション (`JSONSerializer`)

- Options クラス: シリアライゼーション設定
  - `simple_mode`: 簡易モード（基本属性のみ）
  - `include_location`: 位置情報を含める
  - `include_original_text`: 元テキストを含める
- 主要メソッド:
  - `serialize(node, options)`: ASTをJSON形式に変換
  - `deserialize(json_data)`: JSONからASTを復元
- 用途: AST構造の保存、デバッグ、ツール連携
- CaptionNode処理:
  - JSON出力では文字列としての`caption`フィールドを出力しない
  - 常に`caption_node`として構造化されたノードを出力
  - デシリアライゼーション時は後方互換性のため文字列も受け入れ可能

### 10. コンパイラー (`Compiler`)

- 目的: Re:VIEWコンテンツからASTを生成
- 連携コンポーネント:
  - `InlineProcessor`: インライン要素の処理
  - `BlockProcessor`: ブロック要素の処理
  - `ListProcessor`: リスト構造の処理（ListParser、NestedListAssemblerと協調）
- パフォーマンス機能: コンパイル時間の計測とトラッキング
- 主要メソッド: `compile_to_ast(chapter)`: チャプターからASTを生成

## 使用例とパターン

### 1. 基本的なAST構造例
```
DocumentNode
├── HeadlineNode (level=1)
│   └── caption_node: CaptionNode
│       └── TextNode (content="Chapter Title")
├── ParagraphNode
│   ├── TextNode (content="This is ")
│   ├── InlineNode (inline_type="b")
│   │   └── TextNode (content="bold")
│   └── TextNode (content=" text.")
└── CodeBlockNode (lang="ruby", code_type="list")
    ├── CodeLineNode
    │   └── TextNode (content="puts 'Hello'")
    └── CodeLineNode
        └── TextNode (content="end")
```

### 2. リーフノードの特徴
以下のノードは子ノードを持たない（リーフノード）：
- `TextNode`: プレーンテキスト
- `ReferenceNode`: 参照情報を持つテキスト（TextNodeのサブクラス）
- `ImageNode`: 画像参照
- `EmbedNode`: 埋め込みコンテンツ

### 3. 特殊な子ノード管理
- `TableNode`: `header_rows`, `body_rows`配列で行を分類管理
- `CodeBlockNode`: `CodeLineNode`の配列で行を管理
- `CaptionNode`: テキストとインライン要素の混合コンテンツ
- `ListNode`: ネストしたリスト構造をサポート

### 4. ノードの位置情報 (`SnapshotLocation`)
- すべてのノードは`location`属性でソースファイル内の位置を保持
- デバッグやエラーレポートに使用

### 5. インライン要素の種類
主要なインライン要素タイプ：
- テキスト装飾: `b`, `i`, `tt`, `u`, `strike`
- リンク: `href`, `link`
- 参照: `img`, `table`, `list`, `chap`, `hd`, `column` (コラム参照)
- 特殊: `fn` (脚注), `kw` (キーワード), `ruby` (ルビ)
- 数式: `m` (インライン数式)
- クロスチャプター参照: `@<column>{chapter|id}` 形式

### 6. ブロック要素の種類
主要なブロック要素タイプ：
- 基本: `quote`, `lead`, `flushright`, `centering`
- コード: `list`, `listnum`, `emlist`, `emlistnum`, `cmd`, `source`
- 表: `table`, `emtable`, `imgtable`
- メディア: `image`, `indepimage`
- コラム: `note`, `memo`, `tip`, `info`, `warning`, `important`, `caution`

## 実装上の注意点

1. ノードの設計原則:
   - ブランチノードは`Node`を継承し、子ノードを持てる
   - リーフノードは`LeafNode`を継承し、子ノードを持てない
   - 同じノードで`content`と`children`を混在させない
   - `to_inline_text()`メソッドを適切にオーバーライドする

2. 循環参照の回避: 親子関係の管理で循環参照が発生しないよう注意

3. データ・クラス構造:
   - 中間表現はイミュータブルなデータクラス（`Data.define`）、ノードはミュータブルな通常クラスという使い分け
   - リーフノードのサブクラスは子ノード配列を持たない、という使い分け

4. 拡張性: 新しいノードタイプの追加が容易な構造
   - Visitorパターンによる処理の分離
   - `visit_method_name()`による動的なメソッドディスパッチ

5. 互換性: 既存のBuilder/Compilerシステムとの互換性維持

6. CaptionNodeの一貫性: キャプションは常に構造化ノード（CaptionNode）として扱い、文字列として保持しない

7. イミュータブル設計: `BlockData`などのデータ構造は`Data.define`を使用し、予測可能性と一貫性を保証

このASTシステムにより、Re:VIEWはテキスト形式から構造化されたデータに変換し、HTML、PDF、EPUB等の様々な出力形式に対応できるようになっています。
