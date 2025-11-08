# Re:VIEW Markdown サポート

Re:VIEWはAST版Markdownコンパイラを通じてGitHub Flavored Markdown（GFM）をサポートしています。この文書では、サポートされているMarkdown機能とRe:VIEW ASTへの変換方法について説明します。

## 概要

Markdownサポートは、Re:VIEWのAST/Rendererアーキテクチャ上に実装されています。Markdownドキュメントは内部的にRe:VIEW ASTに変換され、従来のRe:VIEWフォーマット（`.re`ファイル）と同等に扱われます。

### アーキテクチャ

Markdownサポートは以下の3つの主要コンポーネントで構成されています：

- Markly: GFM拡張を備えた高速CommonMarkパーサー（外部gem）
- MarkdownCompiler: MarkdownドキュメントをRe:VIEW ASTにコンパイルする統括クラス
- MarkdownAdapter: Markly ASTをRe:VIEW ASTに変換するアダプター層
- MarkdownHtmlNode: HTML要素の解析とコラムマーカーの検出を担当（内部使用）

### サポートされている拡張機能

以下のGitHub Flavored Markdown拡張機能が有効化されています：
- strikethrough: 取り消し線（`~~text~~`）
- table: テーブル（パイプスタイル）
- autolink: オートリンク（`http://example.com`を自動的にリンクに変換）
- tagfilter: タグフィルタリング（危険なHTMLタグを無効化）

### Re:VIEW独自の拡張

標準的なGFMに加えて、以下のRe:VIEW独自の拡張機能もサポートされています：

- コラム構文: HTMLコメント（`<!-- column: Title -->`）または見出し（`### [column] Title`）を使用したコラムブロック
- 自動コラムクローズ: 見出しレベルに基づくコラムの自動クローズ機能

## Markdown基本記法

Re:VIEWは[CommonMark](https://commonmark.org/)および[GitHub Flavored Markdown（GFM）](https://github.github.com/gfm/)の仕様に準拠しています。標準的なMarkdown記法の詳細については、これらの公式仕様を参照してください。

### サポートされている主な要素

以下のMarkdown要素がRe:VIEW ASTに変換されます：

| Markdown記法 | 説明 | Re:VIEW AST |
|------------|------|-------------|
| 段落 | 空行で区切られたテキストブロック | `ParagraphNode` |
| 見出し（`#`〜`######`） | 6段階の見出しレベル | `HeadlineNode` |
| 太字（`**text**`） | 強調表示 | `InlineNode(:b)` |
| イタリック（`*text*`） | 斜体表示 | `InlineNode(:i)` |
| コード（`` `code` ``） | インラインコード | `InlineNode(:code)` |
| リンク（`[text](url)`） | ハイパーリンク | `InlineNode(:href)` |
| 取り消し線（`~~text~~`） | 取り消し線（GFM拡張） | `InlineNode(:del)` |
| 箇条書きリスト（`*`, `-`, `+`） | 順序なしリスト | `ListNode(:ul)` |
| 番号付きリスト（`1.`, `2.`） | 順序付きリスト | `ListNode(:ol)` |
| コードブロック（` ``` `） | 言語指定可能なコードブロック | `CodeBlockNode` |
| 引用（`>`） | 引用ブロック | `BlockNode(:quote)` |
| テーブル（GFM） | パイプスタイルのテーブル | `TableNode` |
| 画像（`![alt](path)`） | 画像（単独行はブロック、行内はインライン） | `ImageNode` / `InlineNode(:icon)` |
| 水平線（`---`, `***`） | 区切り線 | `BlockNode(:hr)` |
| HTMLブロック | 生HTML（保持される） | `EmbedNode(:html)` |

### 変換例

```markdown
## 見出し

これは **太字** と *イタリック* を含む段落です。`インラインコード`も使えます。

* 箇条書き項目1
* 箇条書き項目2

詳細は[公式サイト](https://example.com)を参照してください。
```

### 画像の扱い

画像は文脈によって異なるASTノードに変換されます：

```markdown
![図1のキャプション](image.png)
```
単独行の画像は `ImageNode`（ブロックレベル）に変換され、Re:VIEWの `//image[image][図1のキャプション]` と同等になります。

```markdown
これは ![アイコン](icon.png) インライン画像です。
```
行内の画像は `InlineNode(:icon)` に変換され、Re:VIEWの `@<icon>{icon.png}` と同等になります。

## コラム（Re:VIEW拡張）

Re:VIEWはMarkdownドキュメント内でコラムブロックをサポートしています。コラムを作成する方法は3つあります：

### 方法1: HTMLコメント構文

```markdown
<!-- column: コラムのタイトル -->

ここにコラムの内容を書きます。

コラム内ではすべてのMarkdown機能を使用できます。

<!-- /column -->
```

タイトルなしのコラムの場合：

```markdown
<!-- column -->

タイトルなしのコラム内容。

<!-- /column -->
```

### 方法2: 見出し構文（明示的な終了）

```markdown
### [column] コラムのタイトル

ここにコラムの内容を書きます。

### [/column]
```

### 方法3: 見出し構文（自動クローズ）

以下の場合にコラムは自動的にクローズされます：
- 同じレベルの見出しに遭遇したとき
- より高いレベル（小さい数字）の見出しに遭遇したとき
- ドキュメントの終わり

```markdown
### [column] コラムのタイトル

ここにコラムの内容を書きます。

### 次のセクション
```

この例では、「次のセクション」の見出しに遭遇したときにコラムが自動的にクローズされます。

ドキュメント終了時の自動クローズの例：

```markdown
### [column] ヒントとコツ

このコラムはドキュメントの最後で自動的にクローズされます。

明示的な終了マーカーは不要です。
```

より高いレベルの見出しでの例：

```markdown
### [column] サブセクションコラム

レベル3のコラム。

## メインセクション

このレベル2の見出しはレベル3のコラムをクローズします。
```

### コラムの自動クローズ規則

- 同じレベル: `### [column]` は別の `###` 見出しが現れるとクローズ
- より高いレベル: `### [column]` は `##` または `#` 見出しが現れるとクローズ
- より低いレベル: `### [column]` は `####` 以下が現れてもクローズされない
- ドキュメント終了: すべての開いているコラムは自動的にクローズ

### コラムのネスト

コラムはネスト可能ですが、見出しレベルに注意してください：

```markdown
## [column] 外側のコラム

外側のコラムの内容。

### [column] 内側のコラム

内側のコラムの内容。

### [/column]

外側のコラムに戻ります。

## [/column]
```

## その他のMarkdown機能

### 改行
- ソフト改行: 単一の改行はスペースに変換
- ハード改行: 行末の2つのスペースで改行を挿入

### HTMLブロック
生のHTMLブロックは `EmbedNode(:html)` として保持され、Re:VIEWの `//embed[html]` と同等に扱われます。インラインHTMLもサポートされます。

## 制限事項と注意点

### ファイル拡張子

Markdownファイルは適切に処理されるために `.md` 拡張子を使用する必要があります。Re:VIEWシステムは拡張子によってファイル形式を自動判別します。

### 画像パス

画像パスはプロジェクトの画像ディレクトリ（デフォルトでは`images/`）からの相対パスか、Re:VIEWの画像パス規約を使用する必要があります。

#### 例
```markdown
![キャプション](sample.png)  <!-- images/sample.png を参照 -->
```

### Re:VIEW固有の機能

Markdownでは以下の制限があります：

#### サポートされていないRe:VIEW固有機能
- `//list`（キャプション付きコードブロック）→ Markdownでは通常のコードブロックとして扱われます
- `//table`（キャプション付き表）→ GFMテーブルは使用できますが、キャプションやラベルは付けられません
- `//footnote`（脚注）→ Markdown内では直接使用できません
- `//cmd`、`//embed`などの特殊なブロック命令
- インライン命令の一部（`@<kw>`、`@<bou>`など）

すべてのRe:VIEW機能にアクセスする必要がある場合は、Re:VIEWフォーマット（`.re`ファイル）を使用してください。

### テーブルのキャプション

GFMテーブルはサポートされていますが、Re:VIEWの`//table`コマンドのようなキャプションやラベルを付ける機能はありません。キャプション付きテーブルが必要な場合は、`.re`ファイルを使用してください。

### コラムのネスト

コラムをネストする場合、見出しレベルに注意が必要です。内側のコラムは外側のコラムよりも高い見出しレベル（大きい数字）を使用してください：

```markdown
## [column] 外側のコラム
外側の内容

### [column] 内側のコラム
内側の内容
### [/column]

外側のコラムに戻る
## [/column]
```

### HTMLコメントの使用

HTMLコメントは特別な目的（コラムマーカーなど）で使用されます。一般的なコメントとして使用する場合は、コラムマーカーと誤認されないように注意してください：

```markdown
<!-- これは通常のコメント（問題なし） -->
<!-- column: と書くとコラムマーカーとして解釈されます -->
```

## 使用方法

### コマンドラインツール

#### AST経由での変換（推奨）

MarkdownファイルをAST経由で各種フォーマットに変換する場合、AST専用のコマンドを使用します：

```bash
# MarkdownをJSON形式のASTにダンプ
review-ast-dump chapter.md > chapter.json

# MarkdownをRe:VIEW形式に変換
review-ast-dump2re chapter.md > chapter.re

# MarkdownからEPUBを生成（AST経由）
review-ast-epubmaker config.yml

# MarkdownからPDFを生成（AST経由）
review-ast-pdfmaker config.yml

# MarkdownからInDesign XMLを生成（AST経由）
review-ast-idgxmlmaker config.yml
```

#### review-ast-compileの使用

`review-ast-compile`コマンドでは、Markdownを指定したフォーマットに直接変換できます：

```bash
# MarkdownをJSON形式のASTに変換
review-ast-compile --target=ast chapter.md

# MarkdownをHTMLに変換（AST経由）
review-ast-compile --target=html chapter.md

# MarkdownをLaTeXに変換（AST経由）
review-ast-compile --target=latex chapter.md

# MarkdownをInDesign XMLに変換（AST経由）
review-ast-compile --target=idgxml chapter.md
```

注意: `--target=ast`を指定すると、生成されたAST構造をJSON形式で出力します。これはデバッグやAST構造の確認に便利です。

#### 従来のreview-compileとの互換性

従来の`review-compile`コマンドも引き続き使用できますが、AST/Rendererアーキテクチャを利用する場合は`review-ast-compile`や各種`review-ast-*maker`コマンドの使用を推奨します：

```bash
# 従来の方式（互換性のため残されています）
review-compile --target=html chapter.md
review-compile --target=latex chapter.md
```

### プロジェクト設定

Markdownを使用するようにプロジェクトを設定：

```yaml
# config.yml
contentdir: src

# CATALOG.yml
CHAPS:
  - chapter1.md
  - chapter2.md
```

### Re:VIEWプロジェクトとの統合

MarkdownファイルとRe:VIEWファイルを同じプロジェクト内で混在させることができます：

```
project/
  ├── config.yml
  ├── CATALOG.yml
  └── src/
      ├── chapter1.re     # Re:VIEWフォーマット
      ├── chapter2.md     # Markdownフォーマット
      └── chapter3.re     # Re:VIEWフォーマット
```

## サンプル

### 完全なドキュメントの例

```markdown
# Rubyの紹介

Rubyはシンプルさと生産性に重点を置いた動的でオープンソースのプログラミング言語です。

## インストール

Rubyをインストールするには、次の手順に従います：

1. [Rubyウェブサイト](https://www.ruby-lang.org/ja/)にアクセス
2. プラットフォームに応じたインストーラーをダウンロード
3. インストーラーを実行

### [column] バージョン管理

Rubyのインストールを管理するには、**rbenv**や**RVM**のようなバージョンマネージャーの使用を推奨します。

### [/column]

## 基本構文

シンプルなRubyプログラムの例：

```ruby
# RubyでHello World
puts "Hello, World!"

# メソッドの定義
def greet(name)
  "Hello, #{name}!"
end

puts greet("Ruby")
```

### 変数

Rubyにはいくつかの変数タイプがあります：

| タイプ | プレフィックス | 例 |
|------|--------|---------|
| ローカル | なし | `variable` |
| インスタンス | `@` | `@variable` |
| クラス | `@@` | `@@variable` |
| グローバル | `$` | `$variable` |

## まとめ

> Rubyはプログラマーを幸せにするために設計されています。
>
> -- まつもとゆきひろ

詳細については、~~公式ドキュメント~~ [Ruby Docs](https://docs.ruby-lang.org/)をご覧ください。

---

Happy coding! ![Rubyロゴ](ruby-logo.png)
```

## 変換の詳細

### ASTノードマッピング

| Markdown要素 | Re:VIEW ASTノード |
|------------------|------------------|
| 段落 | `ParagraphNode` |
| 見出し | `HeadlineNode` |
| 太字 | `InlineNode(:b)` |
| イタリック | `InlineNode(:i)` |
| コード | `InlineNode(:code)` |
| リンク | `InlineNode(:href)` |
| 取り消し線 | `InlineNode(:del)` |
| 箇条書きリスト | `ListNode(:ul)` |
| 番号付きリスト | `ListNode(:ol)` |
| リスト項目 | `ListItemNode` |
| コードブロック | `CodeBlockNode` |
| 引用 | `BlockNode(:quote)` |
| テーブル | `TableNode` |
| テーブル行 | `TableRowNode` |
| テーブルセル | `TableCellNode` |
| 単独画像 | `ImageNode` |
| インライン画像 | `InlineNode(:icon)` |
| 水平線 | `BlockNode(:hr)` |
| HTMLブロック | `EmbedNode(:html)` |
| コラム（HTMLコメント/見出し） | `ColumnNode` |
| コードブロック行 | `CodeLineNode` |

### 位置情報の追跡

すべてのASTノードには以下を追跡する位置情報（`SnapshotLocation`）が含まれます：
- ソースファイル名
- 行番号

これにより正確なエラー報告とデバッグが可能になります。

### 実装アーキテクチャ

Markdownサポートは以下の3つの主要コンポーネントから構成されています：

#### 1. MarkdownCompiler

`MarkdownCompiler`は、Markdownドキュメント全体をRe:VIEW ASTにコンパイルする責務を持ちます。

**主な機能:**
- Marklyパーサーの初期化と設定
- GFM拡張機能の有効化（strikethrough, table, autolink, tagfilter）
- MarkdownAdapterとの連携
- AST生成の統括

#### 2. MarkdownAdapter

`MarkdownAdapter`は、Markly ASTをRe:VIEW ASTに変換するアダプター層です。

**主な機能:**
- Markly ASTの走査と変換
- 各Markdown要素の対応するRe:VIEW ASTノードへの変換
- コラムスタックの管理（ネストと自動クローズ）
- リストスタックとテーブルスタックの管理
- インライン要素の再帰的処理

**特徴:**
- コラムの自動クローズ: 同じレベル以上の見出しでコラムを自動的にクローズ
- スタンドアローン画像の検出: 段落内に単独で存在する画像をブロックレベルの`ImageNode`に変換
- コンテキストスタックによる入れ子構造の管理

#### 3. MarkdownHtmlNode（内部使用）

`MarkdownHtmlNode`は、Markdown内のHTML要素を解析し、特別な意味を持つHTMLコメント（コラムマーカーなど）を識別するための補助ノードです。

**主な機能:**
- HTMLコメントの解析
- コラム開始マーカー（`<!-- column: Title -->`）の検出
- コラム終了マーカー（`<!-- /column -->`）の検出
- コラムタイトルの抽出

**特徴:**
- このノードは最終的なASTには含まれず、変換処理中にのみ使用されます
- HTMLコメントが特別な意味を持つ場合は適切なASTノード（`ColumnNode`など）に変換されます
- 一般的なHTMLブロックは`EmbedNode(:html)`として保持されます

### 変換処理の流れ

1. **解析フェーズ**: MarklyがMarkdownをパースしてMarkly AST（CommonMark準拠）を生成
2. **変換フェーズ**: MarkdownAdapterがMarkly ASTを走査し、各要素をRe:VIEW ASTノードに変換
3. **後処理フェーズ**: コラムやリストなどの入れ子構造を適切に閉じる

```ruby
# 変換の流れ
markdown_text → Markly.parse → Markly AST
                                      ↓
                              MarkdownAdapter.convert
                                      ↓
                               Re:VIEW AST
```

### コラム処理の詳細

コラムは2つの異なる構文でサポートされており、それぞれ異なる方法で処理されます：

#### HTMLコメント構文
- `process_html_block`メソッドで検出
- `MarkdownHtmlNode`を使用してコラムマーカーを識別
- 明示的な終了マーカー（`<!-- /column -->`）が必要

#### 見出し構文
- `process_heading`メソッドで検出
- 見出しテキストから`[column]`マーカーを抽出
- 自動クローズ機能をサポート（同じ/より高いレベルの見出しで自動的にクローズ）
- 明示的な終了マーカー（`### [/column]`）も使用可能

両方の構文とも最終的に同じ`ColumnNode`構造を生成します。

## 高度な機能

### カスタム処理

`MarkdownAdapter` クラスを拡張してカスタム処理を追加できます：

```ruby
class CustomMarkdownAdapter < ReVIEW::AST::MarkdownAdapter
  # メソッドをオーバーライドして動作をカスタマイズ
end
```

### Rendererとの統合

Markdownから生成されたASTは、すべてのRe:VIEW AST Rendererで動作します：
- HTMLRenderer
- LaTeXRenderer
- IDGXMLRenderer（InDesign XML）
- その他のカスタムRenderer

AST構造を経由することで、Markdownで書かれた文書も従来のRe:VIEWフォーマット（`.re`ファイル）と同じように処理され、同じ出力品質を実現できます。

## テスト

Markdownサポートの包括的なテストは `test/ast/test_markdown_adapter.rb` と `test/ast/test_markdown_compiler.rb` にあります。

テストの実行：

```bash
bundle exec rake test
```

特定のMarkdownテストの実行：

```bash
ruby test/ast/test_markdown_adapter.rb
ruby test/ast/test_markdown_compiler.rb
```

## 参考資料

- [CommonMark仕様](https://commonmark.org/)
- [GitHub Flavored Markdown仕様](https://github.github.com/gfm/)
- [Markly Ruby Gem](https://github.com/gjtorikian/markly)
- [Re:VIEWフォーマットドキュメント](format.md)
- [AST概要](ast.md)
- [ASTアーキテクチャ詳細](ast_architecture.md)
- [ASTノード詳細](ast_node.md)
