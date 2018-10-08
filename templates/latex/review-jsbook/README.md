review-jsbook.cls Users Guide
====================

現時点における最新版 `jsbook.cls  2018/06/23 jsclasses (okumura, texjporg)` をベースに、Re:VIEW向けreview-jsbook.clsを実装しました。

過去のRe:VIEW 2でjsbook.clsで作っていた資産を、ほとんどそのまま Re:VIEW 3でも利用できます。

## 特徴

 * クラスオプション `cameraready` により、「印刷用」、「電子用」の用途を明示的な意思表示として与えてることで、用途に応じたPDFファイル生成を行えます。
 * （基本的に）クラスオプションを `<key>=<value>` で与えられます。
 * クラスオプション内で、用紙サイズや基本版面を自由に設計できます。

ここで、クラスオプションとは、親LaTeX文章ファイルにおいて、以下のような位置にカンマ（,）区切りで記述するオプションです。

```latex
\documentclass[クラスオプションたち（省略可能）]{review-jsbook]
```

## Re:VIEWで利用する

クラスオプションオプションたちは、Re:VIEW設定ファイル config.yaml 内の texdocumentclass において、以下のような位置に記述します。

```yaml
texdocumentclass: ["review-jsbook", "クラスオプションたち（省略可能）"]
```


## 利用可能なクラスオプションたち

### 用途別PDFデータ作成 `cameraready=<用途名>`

印刷用 `print`、電子用 `ebook` のいずれかの用途名を指定します。

 * `print`［デフォルト］：印刷用PDFファイルを生成します。
   * トンボあり、デジタルトンボあり（gentombowパッケージ経由）、hyperrefパッケージを`draft`モードで読み込み
 * `ebook`：電子用PDFファイルを生成します。
   * トンボなし、hyperrefパッケージを読み込み

### 特定の用紙サイズ `paper=<用紙サイズ>`

jsbook.clsで利用可能な特定の用紙サイズを指定できます。

 * `a3` 
 * `a4` 
 * `a5`［デフォルト］
 * `a6` 
 * `b4`：JIS B4 
 * `b5`：JIS B5
 * `b6`：JIS B6 
 * `a4var`：210mm x 283mm
 * `b5var`：182mm x 230mm
 * `letter`
 * `legal`
 * `executive`


### トンボ用紙サイズ `tombopaper=<用紙サイズ>`

トンボ用紙サイズを指定できます。
［デフォルト］値は自動判定します。


### カスタム用紙サイズ `paperwidth=<用紙横幅>`, `paperheight=<用紙縦幅>`

カスタム用紙サイズ `paperwidth=<用紙横幅>`, `paperheight=<用紙縦幅>` （両方とも与える必要があります）を与えることで、特定の用紙サイズで設定できない用紙サイズを与えられます。

例えば、とあるB5変形 `paperwidth=182mm`, `paperheight=235mm`。


### 基本版面設計 `Q=<級数>`, `W=<字詰>`, `L=<行数>`, `H=<行送り>` , `head=<天>`, `gutter=<ノド>`

基本版面 QWLH, 天、ノドを与えます。
天、ノドをそれぞれ与えない場合、それぞれ天地、左右中央になります。

 * `Q=13`［デフォルト］：文字サイズを級数（1Q = 1H = 0.25mm）で与えます。
 * `W=35`［デフォルト］：1行字詰めを与えます。
 * `L=32`［デフォルト］：行数を与えます。
 * `H=22`［デフォルト］：行送り（1Q = 1H = 0.25mm）を与えます。
 * `head=<幅>`：天を与えます。［デフォルト］は天地中央です。
 * `gutter=<幅>`：ノドを与えます。［デフォルト］は左右中央です。

例をいくつか上げます。

 * paper=a5, Q=13, W=35, L=32, H=22,
 * paper=a5, Q=14, W=38, L=34, H=20.5, head=20mm, gutter=20mm,
 * paper=b5, Q=13, W=43, L=35, H=24, 
 * paper=b5, Q=14, W=40, L=34, H=25.5, 


さらに、ヘッダー、フッターに関する位置調整は、TeXのパラメータ `\headheight`, `\headsep`, `\footskip` に対応して、それぞれ `headheight`, `headsep`, `footskip` を与えられます。


## 標準でreview-jsbook.clsを実行したときのjsbook.clsとの違い

 * jsbook.clsのクラスオプション `nomag`：用紙サイズや版面設計は、すべてreview-jsbook側で行います。
 * hyperrefパッケージ：あらかじめhyperrefパッケージを組み込んで、`cameraready`オプションにより用途別で挙動を制御しています。
 * 各種相対フォントサイズコマンド`\small`, `\footnotesize`, `\scriptsize`, `\tiny`, `\large`, `\Large`, `\LARGE`, `\huge`, `\Huge`, `\HUGE` は、級数ベースに書き換えています。あまりちゃんと実装せずに、いい加減に変えていますが、本文級数が12Qから15Qまでぐらいであれば、それなりに大丈夫と思います。


## おわりに
Re:VIEW用途でなくても、review-jsbook.clsを利用できると思います。

Re:VIEW 3リリースにせまられて、review-jsbook.clsを急いで実装しました。
何かあれば、Re:VIEW upstreamであるGitHub kmuto/reviewのissueに上げていただければ、必要に応じて、review-jsbook.clsの対応も検討いたします。

以上です。
