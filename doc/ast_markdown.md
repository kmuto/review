# Re:VIEW Markdown サポート

Re:VIEWはAST版Markdownコンパイラを通じてGitHub Flavored Markdown（GFM）をサポートしています。この文書では、サポートされているMarkdown機能とRe:VIEW ASTへの変換方法について説明します。

## 概要

Markdownサポートは、Re:VIEWのAST/Rendererアーキテクチャ上に実装されています。Markdownドキュメントは内部的にRe:VIEW ASTに変換され、従来のRe:VIEWフォーマット（`.re`ファイル）と同等に扱われます。

### 双方向変換のサポート

Re:VIEWは以下の双方向変換をサポートしています：

1. Markdown → AST → 各種フォーマット: MarkdownCompilerを使用してMarkdownをASTに変換し、各種Rendererで出力
2. Re:VIEW → AST → Markdown: Re:VIEWフォーマットをASTに変換し、MarkdownRendererでMarkdown形式に出力

この双方向変換により、以下が可能になります：
- Markdownで執筆した文書をPDF、EPUB、HTMLなどに変換
- Re:VIEWで執筆した文書をMarkdown形式に変換してGitHubなどで公開
- 異なるフォーマット間でのコンテンツの相互変換

### アーキテクチャ

Markdownサポートは双方向の変換をサポートしています：

#### Markdown → Re:VIEW AST（入力）

- Markly: GFM拡張を備えた高速CommonMarkパーサー（外部gem）
- MarkdownCompiler: MarkdownドキュメントをRe:VIEW ASTにコンパイルする統括クラス
- MarkdownAdapter: Markly ASTをRe:VIEW ASTに変換するアダプター層
- MarkdownHtmlNode: HTML要素の解析とコラムマーカーの検出を担当（内部使用）

#### Re:VIEW AST → Markdown（出力）

- MarkdownRenderer: Re:VIEW ASTをMarkdown形式で出力するレンダラー
  - キャプションは`**Caption**`形式で出力
  - 画像は`![alt](path)`形式で出力
  - テーブルはGFMパイプスタイルで出力
  - 脚注は`[^id]`記法で出力

### サポートされている拡張機能

以下のGitHub Flavored Markdown拡張機能が有効化されています：
- strikethrough: 取り消し線（`~~text~~`）
- table: テーブル（パイプスタイル）
- autolink: オートリンク（`http://example.com`を自動的にリンクに変換）

### Re:VIEW独自の拡張

標準的なGFMに加えて、以下のRe:VIEW独自の拡張機能もサポートされています：

- コラム構文: 見出し（`### [column] Title`）で開始し、HTMLコメント（`<!-- /column -->`）または自動クローズで終了するコラムブロック
- 自動コラムクローズ: 見出しレベルに基づくコラムの自動クローズ機能
- 属性ブロック: Pandoc/kramdown互換の`{#id caption="..."}`構文によるID・キャプション指定
- Re:VIEW参照記法: `@<img>{id}`、`@<list>{id}`、`@<table>{id}`による図表参照
- 脚注サポート: Markdown標準の`[^id]`記法による脚注

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
| コードブロック+属性 | `{#id caption="..."}`でID・キャプション指定 | `CodeBlockNode(:list)` |
| 引用（`>`） | 引用ブロック | `BlockNode(:quote)` |
| テーブル（GFM） | パイプスタイルのテーブル | `TableNode` |
| テーブル+属性 | `{#id caption="..."}`でID・キャプション指定 | `TableNode`（ID・キャプション付き） |
| 画像（`![alt](path)`） | 画像（単独行はブロック、行内はインライン） | `ImageNode` / `InlineNode(:icon)` |
| 画像+属性 | `{#id caption="..."}`でID・キャプション指定 | `ImageNode`（ID・キャプション付き） |
| 水平線（`---`, `***`） | 区切り線 | `BlockNode(:hr)` |
| HTMLブロック | 生HTML（保持される） | `EmbedNode(:html)` |
| 脚注参照（`[^id]`） | 脚注への参照 | `InlineNode(:fn)` + `ReferenceNode` |
| 脚注定義（`[^id]: 内容`） | 脚注の定義 | `FootnoteNode` |
| Re:VIEW参照（`@<type>{id}`） | 図表リストへの参照 | `InlineNode(type)` + `ReferenceNode` |

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

#### 単独行の画像（ブロックレベル）

```markdown
![図1のキャプション](image.png)
```
単独行の画像は `ImageNode`（ブロックレベル）に変換され、Re:VIEWの `//image[image][図1のキャプション]` と同等になります。

#### IDとキャプションの明示的指定

属性ブロック構文を使用して、画像にIDとキャプションを明示的に指定できます。属性ブロックは画像と同じ行に書くことも、次の行に書くこともできます：

```markdown
![代替テキスト](images/sample.png){#fig-sample caption="サンプル画像"}
```

または、次の行に書く形式：

```markdown
![代替テキスト](images/sample.png)
{#fig-sample caption="サンプル画像"}
```

これにより、`ImageNode`に`id="fig-sample"`と`caption="サンプル画像"`が設定されます。属性ブロックのキャプションが指定されている場合、それが優先されます。IDのみを指定することも可能です：

```markdown
![サンプル画像](images/sample.png){#fig-sample}
```

または：

```markdown
![サンプル画像](images/sample.png)
{#fig-sample}
```

この場合、代替テキスト「サンプル画像」がキャプションとして使用されます。

#### インライン画像

```markdown
これは ![アイコン](icon.png) インライン画像です。
```
行内の画像は `InlineNode(:icon)` に変換され、Re:VIEWの `@<icon>{icon.png}` と同等になります。

## コラム（Re:VIEW拡張）

Re:VIEWはMarkdownドキュメント内でコラムブロックをサポートしています。コラムは見出し構文で開始し、HTMLコメントまたは自動クローズで終了します。

### 方法1: 見出し構文 + HTMLコメントで終了

```markdown
### [column] コラムのタイトル

ここにコラムの内容を書きます。

コラム内ではすべてのMarkdown機能を使用できます。

<!-- /column -->
```

タイトルなしのコラムの場合：

```markdown
### [column]

タイトルなしのコラム内容。

<!-- /column -->
```

### 方法2: 見出し構文（自動クローズ）

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

<!-- /column -->

外側のコラムに戻ります。

<!-- /column -->
```

## コードブロックとリスト（Re:VIEW拡張）

### キャプション付きコードブロック

コードブロックにIDとキャプションを指定して、Re:VIEWの`//list`コマンドと同等の機能を使用できます。属性ブロックは言語指定の後に記述します：

````markdown
```ruby {#lst-hello caption="挨拶プログラム"}
def hello(name)
  puts "Hello, #{name}!"
end
```
````

属性ブロック`{#lst-hello caption="挨拶プログラム"}`を言語指定の後に記述することで、コードブロックにIDとキャプションが設定されます。この場合、`CodeBlockNode`の`code_type`は`:list`になります。

IDのみを指定することも可能です：

````markdown
```ruby {#lst-example}
# コード
```
````

属性ブロックを指定しない通常のコードブロックは`code_type: :emlist`として扱われます。

注意：コードブロックの属性ブロックは、開始のバッククオート行に記述する必要があります。画像やテーブルとは異なり、次の行に書くことはできません。

## テーブル（Re:VIEW拡張）

### キャプション付きテーブル

GFMテーブルにIDとキャプションを指定できます。属性ブロックはテーブルの直後の行に記述します：

```markdown
| 名前 | 年齢 | 職業 |
|------|------|------|
| Alice| 25   | エンジニア |
| Bob  | 30   | デザイナー |
{#tbl-users caption="ユーザー一覧"}
```

属性ブロック`{#tbl-users caption="ユーザー一覧"}`をテーブルの直後の行に記述することで、テーブルにIDとキャプションが設定されます。これはRe:VIEWの`//table`コマンドと同等の機能です。

## 図表参照（Re:VIEW拡張）

### Re:VIEW記法による参照

Markdown内でRe:VIEWの参照記法を使用して、図・表・リストを参照できます：

```markdown
![サンプル画像](images/sample.png)
{#fig-sample caption="サンプル画像"}

図@<img>{fig-sample}を参照してください。
```

```markdown
```ruby {#lst-hello caption="挨拶プログラム"}
def hello
  puts "Hello, World!"
end
```

リスト@<list>{lst-hello}を参照してください。
```

```markdown
| 名前 | 年齢 |
|------|------|
| Alice| 25   |
{#tbl-users caption="ユーザー一覧"}

表@<table>{tbl-users}を参照してください。
```

この記法はRe:VIEWの標準的な参照記法と同じです。参照先のIDは、上記の属性ブロックで指定したIDと対応している必要があります。

参照は後続の処理で適切な番号に置き換えられます：
- `@<img>{fig-sample}` → 「図1.1」
- `@<list>{lst-hello}` → 「リスト1.1」
- `@<table>{tbl-users}` → 「表1.1」

### 参照の解決

参照は後続の処理（参照解決フェーズ）で適切な図番・表番・リスト番号に置き換えられます。AST内では`InlineNode`と`ReferenceNode`の組み合わせとして表現されます。

## 脚注（Re:VIEW拡張）

Markdown標準の脚注記法をサポートしています：

### 脚注の使用

```markdown
これは脚注のテストです[^1]。

複数の脚注も使えます[^note]。

[^1]: これは最初の脚注です。

[^note]: これは名前付き脚注です。
  複数行の内容も
  サポートします。
```

脚注参照`[^id]`と脚注定義`[^id]: 内容`を使用できます。脚注定義は複数行にまたがることができ、インデントされた行は前の脚注の続きとして扱われます。

### FootnoteNodeへの変換

脚注定義は`FootnoteNode`に変換され、Re:VIEWの`//footnote`コマンドと同等に扱われます。脚注参照は`InlineNode(:fn)`として表現されます。

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

以下のRe:VIEW機能がMarkdown内でサポートされています：

#### サポートされているRe:VIEW機能
- `//list`（キャプション付きコードブロック）→ 属性ブロック`{#id caption="..."}`で指定可能
- `//table`（キャプション付き表）→ 属性ブロック`{#id caption="..."}`で指定可能
- `//image`（キャプション付き画像）→ 属性ブロック`{#id caption="..."}`で指定可能
- `//footnote`（脚注）→ Markdown標準の`[^id]`記法をサポート
- 図表参照（`@<img>{id}`、`@<list>{id}`、`@<table>{id}`）→ 完全サポート
- コラム（`//column`）→ HTMLコメントまたは見出し記法でサポート

#### サポートされていないRe:VIEW固有機能
- `//cmd`、`//embed`などの特殊なブロック命令
- インライン命令の一部（`@<kw>`、`@<bou>`、`@<ami>`など）
- 複雑なテーブル機能（セル結合、カスタム列幅など）

すべてのRe:VIEW機能にアクセスする必要がある場合は、Re:VIEWフォーマット（`.re`ファイル）を使用してください。

### コラムのネスト

コラムをネストする場合、見出しレベルに注意が必要です。内側のコラムは外側のコラムよりも高い見出しレベル（大きい数字）を使用してください：

```markdown
## [column] 外側のコラム
外側の内容

### [column] 内側のコラム
内側の内容
<!-- /column -->

外側のコラムに戻る
<!-- /column -->
```

### HTMLコメントの使用

HTMLコメント`<!-- /column -->`はコラムの終了マーカーとして使用されます。一般的なコメントとして使用する場合は、`/column`と書かないように注意してください：

```markdown
<!-- これは通常のコメント（問題なし） -->
<!-- /column と書くとコラム終了マーカーとして解釈されます -->
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

# MarkdownをMarkdownに変換（AST経由、正規化・整形）
review-ast-compile --target=markdown chapter.md
```

注意: `--target=ast`を指定すると、生成されたAST構造をJSON形式で出力します。これはデバッグやAST構造の確認に便利です。

#### Re:VIEW形式からMarkdown形式への変換

Re:VIEWフォーマット（`.re`ファイル）をMarkdown形式に変換することもできます：

```bash
# Re:VIEWファイルをMarkdownに変換
review-ast-compile --target=markdown chapter.re > chapter.md
```

この変換により、Re:VIEWで書かれた文書をMarkdown形式で出力できます。MarkdownRendererは以下の形式で出力します：

- コードブロック: キャプションは`**Caption**`形式で出力され、その後にフェンスドコードブロックが続きます
- テーブル: キャプションは`**Caption**`形式で出力され、その後にGFMパイプスタイルのテーブルが続きます
- 画像: Markdown標準の`![alt](path)`形式で出力されます
- 脚注: Markdown標準の`[^id]`記法で出力されます

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

````markdown
# Rubyの紹介

Rubyはシンプルさと生産性に重点を置いた動的でオープンソースのプログラミング言語です[^intro]。

## インストール

Rubyをインストールするには、次の手順に従います：

1. [Rubyウェブサイト](https://www.ruby-lang.org/ja/)にアクセス
2. プラットフォームに応じたインストーラーをダウンロード
3. インストーラーを実行

### [column] バージョン管理

Rubyのインストールを管理するには、**rbenv**や**RVM**のようなバージョンマネージャーの使用を推奨します。

<!-- /column -->

## 基本構文

シンプルなRubyプログラムの例をリスト@<list>{lst-hello}に示します：

```ruby {#lst-hello caption="RubyでHello World"}
# RubyでHello World
puts "Hello, World!"

# メソッドの定義
def greet(name)
  "Hello, #{name}!"
end

puts greet("Ruby")
```

### 変数

Rubyにはいくつかの変数タイプがあります（表@<table>{tbl-vars}参照）：

| タイプ | プレフィックス | 例 |
|------|--------|---------|
| ローカル | なし | `variable` |
| インスタンス | `@` | `@variable` |
| クラス | `@@` | `@@variable` |
| グローバル | `$` | `$variable` |
{#tbl-vars caption="Rubyの変数タイプ"}

## プロジェクト構造

典型的なRubyプロジェクトの構造を図@<img>{fig-structure}に示します：

![プロジェクト構造図](images/ruby-structure.png)
{#fig-structure caption="Rubyプロジェクトの構造"}

## まとめ

> Rubyはプログラマーを幸せにするために設計されています。
>
> -- まつもとゆきひろ

詳細については、~~公式ドキュメント~~ [Ruby Docs](https://docs.ruby-lang.org/)をご覧ください[^docs]。

---

Happy coding! ![Rubyロゴ](ruby-logo.png)

[^intro]: Rubyは1995年にまつもとゆきひろ氏によって公開されました。

[^docs]: 公式ドキュメントには豊富なチュートリアルとAPIリファレンスが含まれています。
````

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
| コードブロック（属性付き） | `CodeBlockNode(:list)` |
| 引用 | `BlockNode(:quote)` |
| テーブル | `TableNode` |
| テーブル（属性付き） | `TableNode`（ID・キャプション付き） |
| テーブル行 | `TableRowNode` |
| テーブルセル | `TableCellNode` |
| 単独画像 | `ImageNode` |
| 単独画像（属性付き） | `ImageNode`（ID・キャプション付き） |
| インライン画像 | `InlineNode(:icon)` |
| 水平線 | `BlockNode(:hr)` |
| HTMLブロック | `EmbedNode(:html)` |
| コラム（HTMLコメント/見出し） | `ColumnNode` |
| コードブロック行 | `CodeLineNode` |
| 脚注定義 `[^id]: 内容` | `FootnoteNode` |
| 脚注参照 `[^id]` | `InlineNode(:fn)` + `ReferenceNode` |
| 図表参照 `@<type>{id}` | `InlineNode(type)` + `ReferenceNode` |

### 位置情報の追跡

すべてのASTノードには以下を追跡する位置情報（`SnapshotLocation`）が含まれます：
- ソースファイル名
- 行番号

これにより正確なエラー報告とデバッグが可能になります。

### 実装アーキテクチャ

Markdownサポートは以下の3つの主要コンポーネントから構成されています：

#### 1. MarkdownCompiler

`MarkdownCompiler`は、Markdownドキュメント全体をRe:VIEW ASTにコンパイルする責務を持ちます。

主な機能:
- Marklyパーサーの初期化と設定
- GFM拡張機能の有効化（strikethrough, table, autolink）
- 脚注サポートの有効化（Markly::FOOTNOTES）
- Re:VIEW inline notation保護（`@<xxx>{id}`記法の保護）
- MarkdownAdapterとの連携
- AST生成の統括

Re:VIEW記法の保護:

MarkdownCompilerは、Marklyによる解析の前にRe:VIEW inline notation（`@<xxx>{id}`）を保護します。Marklyは`@<xxx>`をHTMLタグとして誤って解釈するため、`@<`をプレースホルダ`@@REVIEW_AT_LT@@`に置換してからパースし、MarkdownAdapterで元に戻します。

#### 2. MarkdownAdapter

`MarkdownAdapter`は、Markly ASTをRe:VIEW ASTに変換するアダプター層です。

##### ContextStack

MarkdownAdapterは内部に`ContextStack`クラスを持ち、AST構築時の階層的なコンテキストを管理します。これにより、以下のような状態管理が統一され、例外安全性が保証されます：

- リスト、テーブル、コラムなどのネストされた構造の管理
- `with_context`メソッドによる例外安全なコンテキスト切り替え（`ensure`ブロックで自動クリーンアップ）
- `find_all`、`any?`メソッドによるスタック内の特定ノード検索
- コンテキストの検証機能（`validate!`）によるデバッグ支援

主な機能:
- Markly ASTの走査と変換
- 各Markdown要素の対応するRe:VIEW ASTノードへの変換
- ContextStackによる統一された階層的コンテキスト管理
- インライン要素の再帰的処理（InlineTokenizerを使用）
- 属性ブロックの解析とID・キャプションの抽出
- Re:VIEW inline notation（`@<xxx>{id}`）の処理

特徴:
- **ContextStackによる例外安全な状態管理**: すべてのコンテキスト（リスト、テーブル、コラム等）を単一のContextStackで管理し、`ensure`ブロックによる自動クリーンアップで例外安全性を保証
- **コラムの自動クローズ**: 同じレベル以上の見出しでコラムを自動的にクローズ。コラムレベルはColumnNode.level属性に保存され、ContextStackから取得可能
- **スタンドアローン画像の検出**: 段落内に単独で存在する画像（属性ブロック付き含む）をブロックレベルの`ImageNode`に変換。`softbreak`/`linebreak`ノードを無視することで、画像と属性ブロックの間に改行があっても正しく認識
- **属性ブロックパーサー**: `{#id caption="..."}`形式の属性を解析してIDとキャプションを抽出
- **Markly脚注サポート**: Marklyのネイティブ脚注機能（Markly::FOOTNOTES）を使用して`[^id]`と`[^id]: 内容`を処理
- **InlineTokenizerによるinline notation処理**: Re:VIEWのinline notation（`@<img>{id}`等）をInlineTokenizerで解析してInlineNodeとReferenceNodeに変換

#### 3. MarkdownHtmlNode（内部使用）

`MarkdownHtmlNode`は、Markdown内のHTML要素を解析し、特別な意味を持つHTMLコメント（コラムマーカーなど）を識別するための補助ノードです。

主な機能:
- HTMLコメントの解析
- コラム終了マーカー（`<!-- /column -->`）の検出

特徴:
- このノードは最終的なASTには含まれず、変換処理中にのみ使用されます
- コラム終了マーカー（`<!-- /column -->`）を検出すると`end_column`メソッドを呼び出し
- 一般的なHTMLブロックは`EmbedNode(:html)`として保持されます

#### 4. MarkdownRenderer

`MarkdownRenderer`は、Re:VIEW ASTをMarkdown形式で出力するレンダラーです。

主な機能:
- Re:VIEW ASTの走査とMarkdown形式への変換
- GFM互換のMarkdown記法での出力
- キャプション付き要素の適切な形式での出力

出力形式:
- コードブロックのキャプション: `**Caption**`形式で出力し、その後にフェンスドコードブロックを出力
- テーブルのキャプション: `**Caption**`形式で出力し、その後にGFMパイプスタイルのテーブルを出力
- 画像: Markdown標準の`![alt](path)`形式で出力
- 脚注参照: `[^id]`形式で出力
- 脚注定義: `[^id]: 内容`形式で出力

特徴:
- 純粋なMarkdown形式での出力を優先
- GFM（GitHub Flavored Markdown）との互換性を重視
- 未解決の参照でもエラーにならず、ref_idをそのまま使用

### 変換処理の流れ

1. **前処理**: MarkdownCompilerがRe:VIEW inline notation（`@<xxx>{id}`）を保護
   - `@<` → `@@REVIEW_AT_LT@@` に置換してMarklyの誤解釈を防止

2. **解析フェーズ**: MarklyがMarkdownをパースしてMarkly AST（CommonMark準拠）を生成
   - GFM拡張（strikethrough, table, autolink）を有効化
   - 脚注サポート（Markly::FOOTNOTES）を有効化

3. **変換フェーズ**: MarkdownAdapterがMarkly ASTを走査し、各要素をRe:VIEW ASTノードに変換
   - ContextStackで階層的なコンテキスト管理
   - 属性ブロック `{#id caption="..."}` を解析してIDとキャプションを抽出
   - Re:VIEW inline notationプレースホルダを元に戻してInlineTokenizerで処理
   - Marklyの脚注ノード（`:footnote_reference`、`:footnote_definition`）をFootnoteNodeとInlineNode(:fn)に変換

4. **後処理フェーズ**: コラムやリストなどの入れ子構造を適切に閉じる
   - ContextStackの`ensure`ブロックによる自動クリーンアップ
   - 未閉じのコラムを検出してエラー報告

```ruby
# 変換の流れ
markdown_text → 前処理（@< のプレースホルダ化）
                         ↓
        Markly.parse（GFM拡張 + 脚注サポート）
                         ↓
                   Markly AST
                         ↓
              MarkdownAdapter.convert
        （ContextStack管理、属性ブロック解析、
         InlineTokenizer処理、脚注変換）
                         ↓
                  Re:VIEW AST
```

### コラム処理の詳細

コラムは見出し構文で開始し、HTMLコメントまたは自動クローズで終了します：

#### コラム開始（見出し構文）
- `process_heading`メソッドで検出
- 見出しテキストから`[column]`マーカーを抽出
- 見出しレベルをColumnNode.level属性に保存してContextStackにpush

#### コラム終了（2つの方法）

1. **HTMLコメント構文**: `<!-- /column -->`
   - `process_html_block`メソッドで検出
   - `MarkdownHtmlNode`を使用してコラム終了マーカーを識別
   - `end_column`メソッドを呼び出してContextStackからpop

2. **自動クローズ**: 同じ/より高いレベルの見出し
   - `auto_close_columns_for_heading`メソッドがContextStackから現在のColumnNodeを取得し、level属性を確認
   - 新しい見出しレベルが現在のコラムレベル以下の場合、コラムを自動クローズ
   - ドキュメント終了時も自動的にクローズ（`close_all_columns`）

コラムの階層はContextStackで管理され、level属性でクローズ判定が行われます。

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
- HTMLRenderer: HTML形式で出力
- LaTeXRenderer: LaTeX形式で出力（PDF生成用）
- IDGXMLRenderer: InDesign XML形式で出力
- MarkdownRenderer: Markdown形式で出力（正規化・整形）
- その他のカスタムRenderer

AST構造を経由することで、Markdownで書かれた文書も従来のRe:VIEWフォーマット（`.re`ファイル）と同じように処理され、同じ出力品質を実現できます。

#### MarkdownRendererの出力例

Re:VIEWフォーマットをMarkdown形式に変換する場合、以下のような出力になります：

Re:VIEW入力例:
````review
= 章タイトル

//list[sample][サンプルコード][ruby]{
def hello
  puts "Hello, World!"
end
//}

リスト@<list>{sample}を参照してください。

//table[data][データ表]{
名前	年齢
-----
Alice	25
Bob	30
//}
````

MarkdownRenderer出力:
`````markdown
# 章タイトル

サンプルコード

```ruby
def hello
  puts "Hello, World!"
end
```

リスト[^sample]を参照してください。

データ表

| 名前 | 年齢 |
| :-- | :-- |
| Alice | 25 |
| Bob | 30 |
`````

キャプションは`**Caption**`形式で出力され、コードブロックやテーブルの直前に配置されます。これにより、人間が読みやすく、かつGFM互換のMarkdownが生成されます。

## テスト

Markdownサポートの包括的なテストが用意されています：

### テストファイル

- `test/ast/test_markdown_adapter.rb`: MarkdownAdapterのテスト
- `test/ast/test_markdown_compiler.rb`: MarkdownCompilerのテスト
- `test/ast/test_markdown_renderer.rb`: MarkdownRendererのテスト
- `test/ast/test_markdown_renderer_fixtures.rb`: フィクスチャベースのMarkdownRendererテスト
- `test/ast/test_renderer_builder_comparison.rb`: RendererとBuilderの出力比較テスト

### テストの実行

```bash
# すべてのテストを実行
bundle exec rake test

# Markdown関連のテストのみ実行
ruby test/ast/test_markdown_adapter.rb
ruby test/ast/test_markdown_compiler.rb
ruby test/ast/test_markdown_renderer.rb

# フィクスチャテストの実行
ruby test/ast/test_markdown_renderer_fixtures.rb
```

### フィクスチャの再生成

MarkdownRendererの出力形式を変更した場合、フィクスチャを再生成する必要があります：

```bash
bundle exec ruby test/fixtures/generate_markdown_fixtures.rb
```

これにより、`test/fixtures/markdown/`ディレクトリ内のMarkdownフィクスチャファイルが最新の出力形式で再生成されます。

## 参考資料

- [CommonMark仕様](https://commonmark.org/)
- [GitHub Flavored Markdown仕様](https://github.github.com/gfm/)
- [Markly Ruby Gem](https://github.com/gjtorikian/markly)
- [Re:VIEWフォーマットドキュメント](format.md)
- [AST概要](ast.md)
- [ASTアーキテクチャ詳細](ast_architecture.md)
- [ASTノード詳細](ast_node.md)
