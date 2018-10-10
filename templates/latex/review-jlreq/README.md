review-jlreq.cls Users Guide (実験版)
====================

[jlreq](https://github.com/abenori/jlreq) は、 [日本語組版処理の要件](https://www.w3.org/TR/jlreq/ja/) の実装を試みた LaTeX クラスファイルです。

Re:VIEW 向けの本テンプレートは、この jlreq クラスを使用し、これまで広く使われてきた jsbook に代わってユーザーが比較的カスタマイズしやすいものを提供することを目的としています。

## 注意!
- 現時点でこのテンプレートは実験段階 (experimental) です。今後の更新でファイルの内容、ファイル名、および紙面表現が大きく変わる可能性が常にあります。
- Re:VIEW の一部の命令に対応する紙面表現はまだ実装されていません。
- LaTeX の知識が十分でないと感じるなら、デフォルトの review-jsbook テンプレートあるいは [TechBoosterで利用しているRe:VIEWのテンプレート](https://github.com/TechBooster/ReVIEW-Template) を利用することをお勧めします。

## セットアップ
1. jlreq クラスを TeXLive 環境にインストールします。`tlmgr install jlreq` あるいはGitHub https://github.com/abenori/jlreq の clone を実行してください。jlreq 自体も開発段階であり、GitHub 上で頻繁に更新されています。
2. `review-init --latex-template review-jlreq プロジェクト名` を実行して新しいプロジェクトを作成します。
3. `config.yml` ファイルで review-jlreq クラスを使うよう設定します。
```
...
texstyle: reviewmacro
texdocumentclass: ["review-jlreq", "book"]
```

既存のプロジェクトを置き換えるには、プロジェクトの `sty` フォルダに `review-jlreq` フォルダ内のファイルを上書きコピーしてください。
