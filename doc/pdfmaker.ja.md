# LaTeX と review-pdfmaker について
Re:VIEW の review-pdfmaker は、フリーソフトウェアの簡易 DTP システム「LaTeX」を呼び出して PDF を作成しています。

そのため、利用にあたっては TeX の環境を別途セットアップしておく必要があります。OS に応じたセットアップについては、以下の TeX Wiki サイトなどを参照してください。

#### TeX Wiki - TeX入手法
* https://texwiki.texjp.org/?TeX入手法

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
