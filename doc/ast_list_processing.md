# AST List Processing Architecture

## Overview

Re:VIEWのASTにおけるリスト処理は、複数のコンポーネントが協調して動作する洗練されたアーキテクチャを採用しています。このドキュメントでは、リスト処理に関わる主要なクラスとその相互関係について詳しく説明します。

## 主要コンポーネント

### 1. AST Node Classes

#### ListNode
`ListNode`は、すべてのリスト型（番号なしリスト、番号付きリスト、定義リスト）を表現する汎用的なノードクラスです。

**主な属性:**
- `list_type`: リストの種類（`:ul`, `:ol`, `:dl`）
- `children`: 子ノード（`ListItemNode`）を格納（標準的なノード構造）

**特徴:**
- 異なるリスト型を統一的に扱える設計
- 標準的なAST構造（`children`）による統一的な処理

#### ListItemNode
`ListItemNode`は、個々のリスト項目を表現します。

**主な属性:**
- `level`: ネストレベル（1から始まる）
- `content`: 項目のテキスト内容（レガシー用）
- `children`: インライン要素や子リストを含む子ノード

**特徴:**
- ネストされたリスト構造をサポート
- インライン要素（強調、リンクなど）を子ノードとして保持可能

### 2. Parser Component

#### ListParser
`ListParser`は、Re:VIEW記法のリストを解析し、構造化されたデータに変換します。

**責務:**
- 生のテキスト行からリスト項目を抽出
- ネストレベルの判定
- 継続行の収集
- 各リスト型（ul/ol/dl）に特化した解析ロジック

**主なメソッド:**
```ruby
def parse_unordered_list(f)
  # * item
  # ** nested item
  # のような記法を解析
end

def parse_ordered_list(f)
  # 1. item
  # 11. nested item
  # のような記法を解析
end

def parse_definition_list(f)
  # : term
  #   definition
  # のような記法を解析
end
```

**データ構造:**
```ruby
ListItemData = Struct.new(
  :type,              # :ul, :ol, :dl
  :level,             # ネストレベル
  :content,           # 項目のテキスト
  :continuation_lines,# 継続行
  :metadata,          # 追加情報（番号、インデントなど）
  keyword_init: true
)
```

### 3. Builder Component

#### NestedListBuilder
`NestedListBuilder`は、`ListParser`が生成したデータから実際のASTノード構造を構築します。

**責務:**
- フラットなリスト項目データをネストされたAST構造に変換
- インライン要素の解析と組み込み
- 親子関係の適切な設定

**主な処理フロー:**
1. `ListItemData`の配列を受け取る
2. レベルに基づいてネスト構造を構築
3. 各項目のコンテンツをインライン解析
4. 完成したAST構造を返す

### 4. Coordinator Component

#### ListASTProcessor
`ListASTProcessor`は、リスト処理全体を調整する高レベルのインターフェースです。

**責務:**
- `ListParser`と`NestedListBuilder`の協調
- コンパイラーへの統一的なインターフェース提供
- レンダリングの制御

**主なメソッド:**
```ruby
def process_unordered_list(f)
  items = @parser.parse_unordered_list(f)
  return if items.empty?
  
  list_node = @builder.build_unordered_list(items)
  add_to_ast_and_render(list_node)
end
```

## 処理フローの詳細

### 1. 番号なしリスト（Unordered List）の処理

```
入力テキスト:
* 項目1
  継続行
** ネストされた項目
* 項目2

処理フロー:
1. Compiler → ListASTProcessor.process_unordered_list(f)
2. ListASTProcessor → ListParser.parse_unordered_list(f)
   - 各行を解析し、ListItemData構造体の配列を生成
   - レベル判定: "*"の数でネストレベルを決定
3. ListASTProcessor → NestedListBuilder.build_unordered_list(items)
   - ListNodeを作成（list_type: :ul）
   - 各ListItemDataに対してListItemNodeを作成
   - ネスト構造を構築
4. ListASTProcessor → AST Compilerに追加 & レンダリング
```

### 2. 番号付きリスト（Ordered List）の処理

```
入力テキスト:
1. 第1項目
11. ネストされた項目
2. 第2項目

処理フロー:
1. レベル判定: 数字の桁数（1=レベル1、11=レベル2）
2. 番号情報をmetadataとして保持
3. それ以外はUnordered Listと同様の処理
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
1. 特殊な構造: ListItemNodeが用語（dt）と定義（dd）の両方を保持
2. 最初の子ノードが用語、残りが定義内容として処理
3. Rendererで適切にdt/ddタグを生成
```

## 重要な設計上の決定

### 1. 責務の分離
- **解析**（ListParser）と**構築**（NestedListBuilder）を明確に分離
- 各コンポーネントが単一の責任を持つ
- テスト可能性と保守性の向上

### 2. 段階的な処理
- テキスト → 構造化データ → ASTノード → レンダリング
- 各段階で適切な抽象化レベルを維持

### 3. 柔軟な拡張性
- 新しいリスト型の追加が容易
- インライン要素の処理を統合
- 異なるレンダラーへの対応

### 4. 統一的な設計
- ListNodeは標準的なAST構造（`children`）のみを使用
- 他のNodeクラスとの一貫性を保持

## クラス関係図

```
                    AST::Compiler
                         |
                         | 使用
                         v
                 ListASTProcessor
                    /         \
                   /           \
              使用 /             \ 使用
                 v               v
           ListParser    NestedListBuilder
                |               |
                | 生成           | 使用
                v               v
          ListItemData    InlineProcessor
                                |
                                | 生成
                                v
                          ListNode (AST)
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
processor = ListASTProcessor.new(ast_compiler)
items = processor.parser.parse_unordered_list(input)
# カスタム処理...
list_node = processor.builder.build_nested_structure(items, :ul)
```

## まとめ

Re:VIEWのASTリスト処理アーキテクチャは、明確な責務分離と段階的な処理により、複雑なリスト構造を効率的に処理します。ListParser、NestedListBuilder、ListASTProcessorの協調により、Re:VIEW記法からASTへの変換、そして最終的なレンダリングまでがスムーズに行われます。

この設計により、新しいリスト型の追加や、異なるレンダリング要件への対応が容易になっています。