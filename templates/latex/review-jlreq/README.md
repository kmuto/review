review-jlreq.cls Users Guide (実験版)
====================

[jlreq](https://github.com/abenori/jlreq) は、 [日本語組版処理の要件](https://www.w3.org/TR/jlreq/ja/) の実装を試みた LaTeX クラスファイルです。

Re:VIEW 向けの本テンプレートは、この jlreq クラスを使用し、これまで広く使われてきた jsbook に代わってユーザーが比較的カスタマイズしやすいものを提供することを目的としています。

## 注意!
- 現時点でこのテンプレートは実験段階 (experimental) です。今後の更新でファイルの内容、ファイル名、および紙面表現が大きく変わる可能性が常にあります。
- Re:VIEW の一部の命令に対応する紙面表現はまだ実装されていません。
- LaTeX の知識が十分でないと感じるなら、デフォルトの review-jsbook テンプレートを利用することをお勧めします。
- jlreq クラスファイル自体、現在も開発段階にあります。本ドキュメントとともに配布している review-jlreq.cls は、jlreq 2018年11月13日時点の abenori_dev ブランチにあるもの (85a9e5b5813325ea905240b145fc93e4a6a8f245) に従っています。

## セットアップ
1. jlreq クラスを TeXLive 環境にインストールします。`tlmgr install jlreq` あるいはGitHub https://github.com/abenori/jlreq の clone を実行してください。jlreq 自体も開発段階であり、GitHub 上で頻繁に更新されています。
2. `review-init --latex-template review-jlreq プロジェクト名` を実行して新しいプロジェクトを作成します。

既存のプロジェクトを置き換えるには、プロジェクトの `sty` フォルダに `review-jlreq` フォルダ内のファイルを上書きコピーしてください。

## 利用可能なクラスオプションたち

クラスオプションオプションたちは、Re:VIEW 設定ファイル config.yml 内の texdocumentclass において、以下のような位置に記述します。

```yaml
texdocumentclass: ["review-jlreq", "クラスオプションたち（省略可能）"]
```

### 用途別 PDF データ作成 `media=<用途名>`

印刷用 `print`、電子用 `ebook` のいずれかの用途名を指定します。

 * `print`［デフォルト］：印刷用 PDF ファイルを生成します。
   * トンボあり、デジタルトンボあり、hyperref パッケージを `draft` モードで読み込み、表紙は入れない
 * `ebook`：電子用PDFファイルを生成します。
   * トンボなし、hyperref パッケージを読み込み、表紙を入れる

### 表紙の挿入有無 `cover=<trueまたはfalse>`

`media` の値によって表紙（config.yml の coverimage に指定した画像）の配置の有無は自動で切り替わりますが、`cover=true` とすれば必ず表紙を入れるようになります。

### 表紙画像のサイズの仕上がり紙面合わせ `cover_fit_page=<trueまたはfalse>`

上記の coverimage で指定する画像ファイルは、原寸を想定しているため、サイズが異なる場合にははみ出たり、小さすぎたりすることになります。できるだけ原寸で用意することを推奨しますが、`cover_fit_page=true` とすれば表紙画像を紙面の仕上がりサイズに合わせて拡縮します。

### 特定の用紙サイズ `paper=<用紙サイズ>`

利用可能な特定の用紙サイズを指定できます。［デフォルト］は a5 です。

 * `a0` 〜 `a10`：A 列
 * `b0` 〜 `b10`：JIS B 列
 * `c0` 〜 `c8`：C 列
 * `a4var`：210mm x 283mm
 * `b5var`：182mm x 230mm
 * `letter`：レター、8.5in x 11in
 * `legal`：リーガル、8.5in x 14in
 * `executive`：エグゼクティブ、7.25in x 10.5in
 * `hagaki`：葉書き、100mm x 148mm
 * `{横幅,縦幅}`：任意の指定サイズ

### トンボ用紙サイズ `tombopaper=<用紙サイズ>` および塗り足し幅 `bleed_margin=<幅>`

`tombopaper` ではトンボ用紙サイズを指定できます。
［デフォルト］値は自動判定します。

`bleed_margin` では塗り足し領域の幅を指定できます。
［デフォルト］3mm になります。

### 基本版面設計 `fontsize=<文字サイズ>`, `baselineskip=<行送り>`, `line_length=<字詰>`, `number_of_lines=<行数>`, `head_space=<天>`, `foot_space=<地>`, `gutter=<ノド>`, `fore_edge=<小口>`, `linegap=<幅>`, `headheight=<幅>`, `headsep=<幅>`, `footskip=<幅>`

基本版面情報を与えます。
天、ノドをそれぞれ与えない場合、それぞれ天地、左右中央になります。

 * `fontsize=10pt`［デフォルト］：標準の文字（normalfontsize）の文字サイズを与えます。pt のほか、Q や mm といった単位も指定可能です。
 * `baselineskip=高さ`：行送りを与えます。［デフォルト］は fontsize の1.7倍です（10pt の場合 17pt）。
 * `line_length=<字詰め幅>`：1行字詰めを与えます。字詰め幅には単位を付ける必要があります。文字数であれば「zw」を使うとよいでしょう（例：35zw＝35文字）。［デフォルト］は紙サイズの 0.75 倍です。
 * `number_of_lines=<行数>`：行数を与えます。［デフォルト］は紙サイズの 0.75 倍です。
 * `head_space=<幅>`：天を与えます。［デフォルト］は天地中央です。
 * `foot_space=<幅>`：地を与えます。［デフォルト］は天地中央です。
 * `gutter=<幅>`：ノドを与えます。［デフォルト］は左右中央です。
 * `fore_edge=<幅>`：小口を与えます。［デフォルト］は左右中央です。
 * `linegap=<幅>`：行送りを baselineskip で指定する代わりに、通常の文字の高さにこのオプションで指定する幅を加えたものを行送りとします。

版面設計の基本としては、以下のどちらかとなります。

 * 文字サイズ・行送り・字詰め・行数から設計：`fontsize` + `baselineskip` + `line_length` + `number_of_lines` + `head_space` + `gutter`
 * 天・地・ノド・小口から設計：（`fontsize` + `baselineskip`） + `head_space` + `foot_space` + `gutter` + `fore_edge`

ほかにもいくつか jlreq 固有の版面設計オプションがあります。詳細については jlreq の README-ja.md を参照してください。

## 開始ページ番号 `startpage=<ページ番号>`

大扉からのページ開始番号を指定します。

［デフォルト］は1です。表紙・表紙裏（表1・表2）のぶんを飛ばしたければ、`startpage=3` とします。

## 通しページ番号（通しノンブル） `serial_pagination=<trueまたはfalse>`

大扉からアラビア数字でページ番号を通すかどうかを指定します。

 * `true`：大扉を開始ページとして、前付（catalog.yml で PREDEF に指定したもの）、さらに本文（catalog.yml で CHAPS に指定したもの）に連続したページ番号をアラビア数字で振ります（通しノンブルと言います）。
 * `false`［デフォルト］：大扉を開始ページとして前付の終わり（通常は目次）までのページ番号をローマ数字で振ります。本文は 1 を開始ページとしてアラビア数字で振り直します（別ノンブルと言います）。

### 隠しノンブル 'hiddenfolio=<プリセット>'

印刷所固有の要件に合わせて、ノドの目立たない位置に小さくノンブルを入れます。
'hiddenfolio` にプリセットを与えることで、特定の印刷所さん対応の隠しノンブルを出力することができます。
利用可能なプリセットは、以下のとおりです。

 * `default`：トンボ左上（塗り足しの外）にページ番号を入れます。
 * `marusho-ink`（丸正インキ）：塗り足し幅を5mmに設定、ノド中央にページ番号を入れます。
 * `nikko-pc`（日光企画）, `shippo`（ねこのしっぽ）：ノド中央にページ番号を入れます。

独自の設定を追加したいときには、review-jlreq.cls の実装を参照してください。

ページ番号は紙面に入れるものと同じものが入ります。アラビア数字で通したいときには、上記の `serial_pagination=true` も指定してください。
