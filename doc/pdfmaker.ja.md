# LaTeX と review-pdfmaker について
Re:VIEW の review-pdfmaker は、フリーソフトウェアの簡易 DTP システム「LaTeX」を呼び出して PDF を作成しています。

そのため、利用にあたっては TeX の環境を別途セットアップしておく必要があります。OS に応じたセットアップについては、以下の TeX Wiki サイトなどを参照してください。

#### TeX Wiki - TeX入手法
* https://texwiki.texjp.org/?TeX入手法

## Re:VIEW バージョンによる変化についての注意
* Re:VIEW 2.0 より、LaTeX コンパイラのデフォルトが pLaTeX から upLaTeX になりました。以下の「upLaTeX について」を参照してください。
* Re:VIEW 2.0 より、image タグに `scale` オプションを使って倍率数値を定義していた場合の挙動が変わりました。以下の「scale オプションの挙動について」を参照してください。
* Re:VIEW 2.0 より、config.yml 等の設定ファイルで使われる `prt` のデフォルトが「発行所」ではなく「印刷所」になりました。「発行所」には `pbl` のほうをお使いください。

## upLaTeX について

2016年4月リリースの Re:VIEW 2.0 より、LaTeX のコンパイラのデフォルトが、「pLaTeX」から「upLaTeX」に切り替わりました。upLaTeX は pLaTeX の内部文字処理を Unicode 対応にしたもので、丸数字（①②…）のように pLaTeXでは otf パッケージが必要だった文字、あるいは韓国語や中国語との混植などを、直接扱うことができます。

ほとんどの pLaTeX 向けのパッケージはそのまま動作しますが、jsbook クラスや otf パッケージなどでは uplatex オプションが必要です。

LaTeX コンパイラコマンドおよびオプションについて、Re:VIEW の設定のデフォルトは次のとおりです。

```yaml
texcommand: uplatex
texoptions: null
texdocumentclass: ["jsbook", "uplatex,oneside"]
dvicommand: dvipdfmx
dvioptions: "-d 5"
```

## 旧来の pLaTeX を使用するには

既存のドキュメントについて、利用しているマクロやパッケージが upLaTeX でうまく動かない、あるいはこれまでと異なる紙面ができてしまう場合は、pLaTeX に戻したいと思うかもしれません。

Re:VIEW 2.0 よりも前のバージョンと同じコンパイラ設定に戻すには、config.yml に次のように記述します。

```yaml
texcommand: platex
texoptions: "-kanji=utf-8"
texdocumentclass: ["jsbook", "oneside"]
dvicommand: dvipdfmx
dvioptions: "-d 5"
```

レイアウト erb ファイル（デフォルトは lib/review/layout.tex.erb）において、upLaTeX と pLaTeX の区別は内部変数 texcompiler で行えます。変数 texcompiler には、パラメータ texcommand の値からフォルダパスとファイル拡張子を除いたものが入っており、pLaTeX の場合は "platex"、upLaTeX の場合は "uplatex" となります。使用例は次のとおりです。

```
<% if texcompiler == "uplatex" %>
\usepackage[deluxe,uplatex]{otf}
<% else %>
\usepackage[deluxe]{otf}
<% end %>
```

## scale オプションの挙動について
Re:VIEW 2.0 より、``//image`` タグの第3オプションに ``scale=倍率`` で数値のみで倍率を指定していたときの挙動が変わりました。以前は「画像ファイルに対する倍率」でしたが、「紙面横幅に対する倍率」となります（もともと数値以外の文字も scale の値に含めていた場合には、変化はありません）。

旧来の「画像ファイルに対する倍率」に戻したいときには、config.yml にパラメータ ``image_scale2width: false`` を指定してください（デフォルトは true）。

```yaml
image_scale2width: false
```
