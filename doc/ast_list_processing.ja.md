# Re:VIEW ASTでのリスト処理アーキテクチャ

## 概要

Re:VIEWのASTにおけるリスト処理は、複数のコンポーネントが協調して動作する洗練されたアーキテクチャを採用しています。このドキュメントでは、リスト処理に関わる主要なクラスとその相互関係について詳しく説明します。

## 主要コンポーネント

### 1. リスト用ASTノードクラス

#### ListNode
`ListNode`は、すべてのリスト型（番号なしリスト、番号付きリスト、定義リスト）を表現する汎用的なノードクラスです。

##### 主な属性
- `list_type`: リストの種類（`:ul`, `:ol`, `:dl`）
- `start_number`: 番号付きリストの開始番号（デフォルト: `nil`）
- `olnum_start`: InDesignのolnum開始値（IDGXML用、デフォルト: `nil`）
- `children`: 子ノード（`ListItemNode`）を格納（標準的なノード構造）

##### 便利メソッド
- `ol?()`: 番号付きリストかどうかを判定
- `ul?()`: 番号なしリストかどうかを判定
- `dl?()`: 定義リストかどうかを判定

##### 特徴
- 異なるリスト型を統一的に扱える設計
- 標準的なAST構造（`children`）による統一的な処理

#### ListItemNode
`ListItemNode`は、個々のリスト項目を表現します。

##### 主な属性
- `level`: ネストレベル（1から始まる）
- `number`: 番号付きリストにおける項目番号（元の入力に由来）
- `item_number`: 番号付きリストの絶対番号（`ListItemNumberingProcessor`によって設定される）
- `item_type`: 定義リストでの`:dt`（用語）/`:dd`（定義）識別子（通常のリストでは`nil`）
- `children`: 定義内容や入れ子のリストを保持する子ノード
- `term_children`: 定義リストの用語部分を保持するための子ノード配列

##### 便利メソッド
- `definition_term?()`: 定義リストの用語項目（`:dt`）かどうかを判定
- `definition_desc?()`: 定義リストの定義項目（`:dd`）かどうかを判定

##### 特徴
- ネストされたリスト構造をサポート
- インライン要素（強調、リンクなど）を子ノードとして保持可能
- 定義リストでは用語（`term_children`）と定義（`children`）を明確に分離
- 番号付きリストでは`item_number`が後処理で自動的に設定される

### 2. 構文解析コンポーネント

#### ListParser
`ListParser`は、Re:VIEW記法のリストを解析し、構造化されたデータに変換します。

##### 責務
- 生のテキスト行からリスト項目を抽出
- ネストレベルの判定
- 継続行の収集
- 各リスト型（ul/ol/dl）に特化した解析ロジック

##### 主なメソッド
```ruby
def parse_unordered_list(f)
  #   * item
  #   ** nested item
  # のような記法を解析
end

def parse_ordered_list(f)
  # 1. item
  # 11. item番号11（ネストではなく実番号）
  # のような記法を解析
end

def parse_definition_list(f)
  # : term
  #   definition
  # のような記法を解析
end
```

##### データ構造
```ruby
ListItemData = Struct.new(
  :type,              # :ul_item, :ol_item, :dt, :dd
  :level,             # ネストレベル（デフォルト: 1）
  :content,           # 項目のテキスト
  :continuation_lines,# 継続行（デフォルト: []）
  :metadata,          # 追加情報（番号、インデントなど、デフォルト: {}）
  keyword_init: true
)
```

#### ListItemDataのメソッド
- `with_adjusted_level(new_level)`: レベルを調整した新しいインスタンスを返す（イミュータブル操作）

##### 補足
- すべてのリスト記法は先頭に空白を含む行としてパーサーに渡される想定です（`lib/review/ast/compiler.rb`でそのような行のみリストとして扱う）。
- 番号付きリストは桁数によるネストをサポートせず、`level`は常に1として解釈されます。

### 3. 組み立てコンポーネント

#### NestedListAssembler
`NestedListAssembler`は、`ListParser`が生成したデータから実際のASTノード構造を組み立てます。

##### 責務
- フラットなリスト項目データをネストされたAST構造に変換
- インライン要素の解析と組み込み
- 親子関係の適切な設定

##### 主な処理フロー
1. `ListItemData`の配列を受け取る
2. レベルに基づいてネスト構造を構築
3. 各項目のコンテンツをインライン解析
4. 完成したAST構造を返す

### 4. 協調コンポーネント

#### ListProcessor
`ListProcessor`は、リスト処理全体を調整する高レベルのインターフェースです。

##### 責務
- `ListParser`と`NestedListAssembler`の協調
- コンパイラーへの統一的なインターフェース提供
- 生成したリストノードをASTに追加

##### 主なメソッド
```ruby
def process_unordered_list(f)
  items = @parser.parse_unordered_list(f)
  return if items.empty?

  list_node = @nested_list_assembler.build_unordered_list(items)
  add_to_ast(list_node)
end
```

##### 公開アクセサー
- `parser`: `ListParser`インスタンスへの読み取り専用アクセス（テストやカスタム用途向け）
- `nested_list_assembler`: `NestedListAssembler`インスタンスへの読み取り専用アクセス（テストやカスタム用途向け）

##### 追加メソッド
- `process_list(f, list_type)`: リスト型を指定した汎用処理メソッド
- `build_list_from_items(items, list_type)`: 事前に解析された項目からリストを構築（テストや特殊用途向け）
- `parse_list_items(f, list_type)`: ASTを構築せずにリスト項目のみを解析（テスト用）

### 5. 後処理コンポーネント

#### ListStructureNormalizer

`//beginchild`と`//endchild`で構成された一時的なリスト要素を正規化し、AST上に正しい入れ子構造を作ります。

##### 責務
- `//beginchild`/`//endchild`ブロックを検出してリスト項目へ再配置
- 同じ型の連続したリストを統合
- 定義リストの段落から用語と定義を分離

#### ListItemNumberingProcessor
番号付きリストの各項目に絶対番号を割り当てます。

##### 責務
- `start_number`から始まる連番の割り当て
- 各`ListItemNode`の`item_number`属性の更新（`attr_accessor`で定義）
- 入れ子構造の有無にかかわらずリスト内の順序に基づく番号付け

##### 処理の詳細
- `ListNode.start_number`を基準に連番を生成
- `start_number`が指定されていない場合は1から開始
- ネストされたリストについても、親リスト内の順序に基づいて番号を付与

これらの後処理は`AST::Compiler`内で常に順番に呼び出され、生成済みのリスト構造を最終形に整えます。

## 処理フローの詳細

### 1. 番号なしリスト（Unordered List）の処理

```
入力テキスト:
   * 項目1
     継続行
   ** ネストされた項目
   * 項目2

処理フロー:
1. Compiler → ListProcessor.process_unordered_list(f)
2. ListProcessor → ListParser.parse_unordered_list(f)
   - 各行を解析し、ListItemData構造体の配列を生成
   - レベル判定: "*"の数でネストレベルを決定
3. ListProcessor → NestedListAssembler.build_unordered_list(items)
   - ListNodeを作成（list_type: :ul）
   - 各ListItemDataに対してListItemNodeを作成
   - ネスト構造を構築
4. ListProcessor → ASTへリストノードを追加
5. AST Compiler → ListStructureNormalizer.process（常に実行）
6. AST Compiler → ListItemNumberingProcessor.process（番号付きリスト向けだが全体フロー内で呼び出される）
```

### 2. 番号付きリスト（Ordered List）の処理

```
入力テキスト:
   1. 第1項目
   11. 第2項目（項目番号11）
   2. 第3項目

処理フロー:
1. ListParserが各行を解析し、`number`メタデータを保持（レベルは常に1）
2. NestedListAssemblerが`start_number`と項目番号を設定しつつリストノードを構築
3. ListProcessorがリストノードをASTに追加
4. AST CompilerでListStructureNormalizer → ListItemNumberingProcessorの順に後処理（ネストは発生しないが絶対番号を割り当て）
```

### 3. 定義リスト（Definition List）の処理

```
入力テキスト:
   : 用語1
     定義内容1
     定義内容2
   : 用語2
     定義内容3

処理フロー:
1. ListParserが各用語行を検出し、後続のインデント行を定義コンテンツとして`continuation_lines`に保持
2. NestedListAssemblerが用語部分を`term_children`に、定義本文を`children`にそれぞれ格納した`ListItemNode`を生成
3. ListStructureNormalizerが段落ベースの定義リストを分割する場合でも、最終的に同じ構造へ統合される
```

## 重要な設計上の決定

### 1. 責務の分離
- 解析（ListParser）と組み立て（NestedListAssembler）を明確に分離
- 後処理（ListStructureNormalizer, ListItemNumberingProcessor）を独立したコンポーネントに分離
- 各コンポーネントが単一の責任を持つ
- テスト可能性と保守性の向上

### 2. 段階的な処理
- テキスト → 構造化データ → ASTノード → AST後処理 → レンダリング
- 各段階で適切な抽象化レベルを維持

### 3. 柔軟な拡張性
- 新しいリスト型の追加が容易
- インライン要素の処理を統合
- 異なるレンダラーへの対応

### 4. 統一的な設計
- ListNodeは標準的なAST構造（`children`）を用い、ListItemNodeは必要なメタデータを属性として保持
- 定義リスト向けの`term_children`など特殊な情報も構造化して管理

## クラス関係図

```
                         AST::Compiler
                              |
                              | 使用
                              v
                        ListProcessor
                         /    |    \
                        /     |     \
                   使用 /      |      \ 使用
                      v       v       v
                ListParser  Nested   InlineProcessor
                           List
                          Assembler
                      |       |         |
                      |       |         |
                  生成 |   使用 |     生成 |
                      v       v         v
               ListItemData  ListNode (AST)
                                |
                                | 後処理
                                v
                       ListStructureNormalizer
                                |
                                | 後処理
                                v
                    ListItemNumberingProcessor
                                |
                                | 含む
                                v
                         ListItemNode (AST)
                                |
                                | 含む
                                v
                    TextNode / InlineNode (AST)
```

## 使用例

### コンパイラーでの使用
```ruby
# AST::Compiler内
def compile_ul_to_ast(f)
  list_processor.process_unordered_list(f)
end
```

### カスタムリスト処理
```ruby
# 独自のリスト処理を実装する場合
processor = ListProcessor.new(ast_compiler)
items = processor.parser.parse_unordered_list(input)
# カスタム処理...
list_node = processor.nested_list_assembler.build_nested_structure(items, :ul)
```

## まとめ

Re:VIEWのASTリスト処理アーキテクチャは、明確な責務分離と段階的な処理により、複雑なリスト構造を効率的に処理します。ListParser、NestedListAssembler、ListProcessor、そして後処理コンポーネント（ListStructureNormalizer、ListItemNumberingProcessor）の協調により、Re:VIEW記法からASTへの変換、構造の正規化、そして最終的なレンダリングまでがスムーズに行われます。

この設計により、新しいリスト型の追加や、異なるレンダリング要件への対応、さらには構造の正規化処理の追加が容易になっています。
