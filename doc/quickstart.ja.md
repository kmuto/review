# Re:VIEWクイックスタートガイド

Re:VIEW は、EWB や RD あるいは Wiki に似た簡易フォーマットで記述したテキストファイルを、目的に応じて各種の形式に変換するツールセットです。

平易な文法ながらも、コンピュータ関係のドキュメント作成のための多くの機能を備えており、テキスト、LaTeX、HTML、XML といった形式に変換できます。独自のカスタマイズも簡単です。

Re:VIEW は GNU Lesser General Public License Version 2.1 に基づいて配布されており、自由に利用、改変、再配布できます。このライセンスは、Re:VIEW を使ってあなたが作成しようとする文書とは無関係であり、あなたの文書はこのライセンスに強制されることはありません。Re:VIEW のツールセットあるいは Re:VIEW を組み込んだシステムを配布あるいは販売しようとしているときには、ライセンスファイル COPYING をよく確認してください。

このドキュメントでは、Re:VIEW のセットアップから変換の例までを簡単に説明します。

## セットアップ

Re:VIEW は Ruby 言語で記述されており、Linux/Unix 互換システムで動作します。Mac OS X および Windows Cygwin でも動作可能です。Ruby gem、Git、Subversion のいずれかを使ってダウンロード・展開します。

なお、Re:VIEW フォーマット自体は文字で表現されたタグが付いている以外は単なるテキストファイルなので、エディタ、OS についてはまったく制限はありません。

### RubyGems を使う場合

機能セットがまとまった区切りごとに、Re:VIEW の開発チームが Re:VIEW の gem を更新しています。

次のように Re:VIEW の gem をインストールします。

```bash
$ gem install review
```

Ruby gem の bin ディレクトリにパスを通すようにしておいてください。

インストール後、最新の gem に追従するには次のようにします。

```bash
$ gem update review
```

### Gitを使う場合

Re:VIEW は GitHub で開発されており、バージョン管理ツールの Git を使って最新の Re:VIEW コードを入手できます。Git は分岐が容易なので、独自のカスタマイズを施すのにも向いています。

初めて取得するときには、次のようにします (コピーを作っています)。

```bash
$ git clone git://github.com/kmuto/review.git
```

review というディレクトリに展開されるので、review/bin にパスを通すようにしておいてください。

最新の開発に追従するには次のようにします。

```bash
$ git pull
```

### Subversionを使う場合

Git の最新コピーは、別のバージョン管理ツールの Subversion 向けにも提供しています (古い環境では Subversion のクライアントしか入っていないことがあります)。

初めて取得するときには、次のようにします (コピーを作っています)。

```bash
$ svn co https://kmuto.jp/svn/review/trunk review
```

review というディレクトリに展開されるので、review/bin にパスを通すようにしておいてください。

最新の開発に追従するには次のようにします。

```
$ svn up
```

# Re:VIEW テキストの作成と変換

セットアップを終えたら、Re:VIEW フォーマットのテキストを作り、変換できるようになります。次に Re:VIEW フォーマットテキストの簡単な例を示します。これを sample.re といった名前で保存します (拡張子も自由ですが、.re 拡張子を推奨します)。


```review
= はじめてのRe:VIEW

//lead{
「Hello, Re:VIEW.」
//}

== Re:VIEWとは

@<b>{Re:VIEW}は、EWBやRDあるいはWikiに似た簡易フォーマットで記述したテキストファイルを、目的に応じて各種の形式に変換するツールセットです。

平易な文法ながらも、コンピュータ関係のドキュメント作成のための多くの機能を備えており、次のような形式に変換できます。

 * テキスト（指示タグ付き）
 * LaTeX
 * HTML
 * XML

現在入手手段としては次の3つがあります。

 1. Ruby gem
 2. Git
 3. Subversion

ホームページは@<tt>{https://github.com/kmuto/review/wiki/}です。
```

テキストファイルの文字エンコーディングには、UTF-8 を使うことをお勧めします。Re:VIEW は日本語文字エンコーディングとして UTF-8、EUC-JP、Shift_JIS、JIS を扱うことができ、入力ファイルについては自動判別、出力ファイルについても選択可能 (デフォルトは UTF-8) ですが、入力・出力のいずれにおいても、使用可能な文字についての制限が少ない UTF-8 が最適です。

次に、章構成ファイルの CHAPS ファイルを同じディレクトリに用意します。このファイルには、Re:VIEW フォーマットファイルの名前を格納します。

* sample.re

CHAPS ファイルの1行目に書いたものが第1章、2行目に書いたものが第2章、……と構成されます (CHAPS に似たものとして、前付けを列挙する PREDEF ファイル、後付けを列挙する POSTDEF ファイルがあります。これらを「カタログファイル」と呼びます)。

sample.re から目的の形式に変換するには、review-compile コマンドを使います。

```bash
$ review-compile --target text sample.re > sample.txt   ←テキストにする
$ review-compile --target html sample.re > sample.html  ←HTMLにする
$ review-compile --target latex sample.re > sample.tex  ←LaTeXにする
$ review-compile --target idgxml sample.re > sample.xml ←XMLにする
```

上記では各ファイル個別に変換することを想定して、標準出力をリダイレクトする書式を掲載していますが、-a オプションを付ければ、CHAPS、PREDEF、POSTDEF に従ってすべてのファイルを変換できます。

```
$ review-compile --target html -a ←すべてのファイルをHTMLにする
```

sample.re を HTML に変換すると、次のようになります。

```html
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
  <meta http-equiv="Content-Style-Type" content="text/css" />
  <meta name="generator" content="Re:VIEW" />
  <title>はじめてのRe:VIEW</title>
</head>
<body>
<h1><a id="h1" />第1章　はじめてのRe:VIEW</h1>
<div class="lead">
<p>「Hello, Re:VIEW.」</p>
</div>

<h2><a id="h1-1" />1.1　Re:VIEWとは</h2>
<p><b>Re:VIEW</b>は、EWBやRDあるいはWikiに似た簡易フォーマットで記述したテキストファイルを、目的に応じて各種の形式に変換するツールセットです。</p>
<p>平易な文法ながらも、コンピュータ関係のドキュメント作成のための多くの機能を備えており、次のような形式に変換できます。</p>
<ul>
<li>テキスト（指示タグ付き）</li>
<li>LaTeX</li>
<li>HTML</li>
<li>XML</li>
</ul>
<p>現在入手手段としては次の3つがあります。</p>
<ol>
<li>Ruby gem</li>
<li>Git</li>
<li>Subversion</li>
</ol>
<p>ホームページは<tt>https://github.com/kmuto/review/wiki/</tt>です。</p>
</body>
</html>
```

Re:VIEW フォーマットについての詳細は、 [format.rdoc](https://github.com/kmuto/review/blob/master/doc/format.rdoc) を参照してください。

review-compile を含め、ほとんどのコマンドは `--help` オプションを付けるとオプションについてのヘルプが表示されます。`review-compile` には多数のオプションがあるので確認してください。

なお、`--target` で毎回指定するのは面倒なので、`review-compile` に対するシンボリックリンクを作成しておくとよいでしょう。「review2...」のコマンド名で呼び出せるようになります。

```bash
$ cd Re:VIEWのインストールされたパス/bin
$ ln -s review-compile review2text
$ ln -s review-compile review2html
$ ln -s review-compile review2latex
$ ln -s review-compile review2idgxml
```

## プリプロセッサ、ボリューム表示

`#@mapfile`、`#@maprange`、`#@mapoutput` のタグを使って、指定のファイルの内容あるいはコマンドの実行結果を挿入できます。挿入・更新を行うには、プリプロセッサとなる review-preproc コマンドを使います。

```bash
$ review-preproc ファイル > 結果ファイル ←標準出力をリダイレクト

## または
$ review-preproc --replace ファイル ←ファイルを更新したもので上書き
```

各章の分量などを表示するには、review-vol コマンドを使います。

```bash
$ review-vol
```

より細かな見出し一覧などを出したいときには、review-index コマンドを使うのもよいでしょう。

```bash
$ review-index --level 掘り下げる見出しレベル数 -a
```

## PDF 化と EPUB 化

review-pdfmaker コマンドで PDF ブックの作成、review-epubmaker コマンドで EPUB ファイルの作成ができます。

PDF を作成するには、TeXLive2012 以上の環境が必要です。EPUB を作成するには、zip コマンドが必要です (MathML も使いたいときには、 [MathML ライブラリ](http://www.hinet.mydns.jp/?mathml.rb)も必要です)。

いずれのコマンドも、必要な設定情報を記した YAML ファイルを引数に指定して実行します。YAML ファイルのサンプルは、 [sample.yml](https://github.com/kmuto/review/blob/master/doc/sample.yml) としてこのドキュメントと同じディレクトリに収録しています。

```bash
$ review-pdfmaker YAMLファイル  ←PDFの作成
$ review-epubmaker YAMLファイル ←EPUBの作成
```

## クレジット

Re:VIEW は、青木峰郎によって最初に作成されました。武藤健志がこの開発・保守を引き継ぎ、2014年3月時点では、武藤健志、高橋征義、角征典が開発・保守を継続しています。

バグ・パッチの報告、開発者用メーリングリストなどについての情報は、

* https://github.com/kmuto/review/wiki

を参照してください。
