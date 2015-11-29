# Version 1.7.1の主な変更点

## バグ修正
* latexbuilderで`//listnum`のキャプションが2重に出力されるバグを修正しました ([#465])
* review-initで生成される雛形を元にEPUB3のファイルを作成するとepubcheck 4.0.1でエラーになるバグを修正しました ([#456])

# Version 1.7.0の主な変更点

## 全般
* Rubocopの設定の追加とそれに伴うリファクタリングを実施しました
* 内部の文字コードをUTF-8に統一しました ([#399])
* Dockerfileを追加しました

## バグ修正
* コードハイライト無効時に、htmlbuilderでlistnumおよびemlistnumにおいて行番号が表示されないバグを修正しました ([#449])

## ビルダーとメーカー

### epubmaker
* 綴じ方向を設定する``direction``パラメータをサポートしました ([#435])

## コードコントリビュータ
* [@snoozer05](https://github.com/snoozer05)

[#399]: https://github.com/kmuto/review/pull/399
[#435]: https://github.com/kmuto/review/pull/435
[#449]: https://github.com/kmuto/review/issues/449

# Version 1.6.0の主な変更点

## 全般
* Ruby 1.8.7のサポートを終了しました
* コードハイライトのデフォルト言語を設定できるようにしました ([#403])
* 見出し参照の際のクォートもI18nを使うようにしました ([#420])
* ``//source`` 記法でハイライトの設定と使用言語のオプションをサポートしました
* 設定ファイルに ``toc`` を追加しました

## バグ修正
* ``@<hd>`` で子要素を指定できないバグを修正しました ([#400])
* プロジェクトのパスに空白スペースが含まれているときにEPUBが正しく生成されないバグを修正しました ([#398])
* ``@<img>``などを付録で使ったときに``appendix_format:alpha``にしておいても``図1.1``のようになってしまうバグを修正しました ([#405])
* ハイライト時にリスト名が表示されないバグを修正しました ([#418])
* i18nの設定がうまくマージされないバグを修正しました ([#423])
* EPUBの表紙画像が厳密にマッチされないバグを修正しました ([#417])
* EPUBのバージョンが3のときに ``htmlversion`` が正しく設定されないバグを修正しました ([#433])

## コマンド

### review-init
* locale.ymlを生成するオプションを追加しました ([#425])

## ビルダーとメーカー

### htmlbuilder
* 章番号を ``span`` タグでマークアップしました ([#415])

### latexbuilder
* ``config["conver"]`` をサポートしました

### pdfmaker
* EPUBMakerと同様のファイルの挿入機能をサポートしました

### epubmaker
* ``toc`` プロパティをconfig.ymlに追加しました ([#413])

## コードコントリビュータ
* [@keiji](https://github.com/keiji)
* [@orangain](https://github.com/orangain)
* [@akinomurasame](https://github.com/akinomurasame)
* [@krororo](https://github.com/krororo)
* [@masarakki](https://github.com/masarakki)

[#398]: https://github.com/kmuto/review/issues/398
[#400]: https://github.com/kmuto/review/issues/400
[#405]: https://github.com/kmuto/review/issues/405
[#403]: https://github.com/kmuto/review/issues/403
[#413]: https://github.com/kmuto/review/issues/413
[#415]: https://github.com/kmuto/review/issues/415
[#417]: https://github.com/kmuto/review/issues/417
[#418]: https://github.com/kmuto/review/issues/418
[#420]: https://github.com/kmuto/review/issues/420
[#423]: https://github.com/kmuto/review/issues/423
[#425]: https://github.com/kmuto/review/issues/425
[#433]: https://github.com/kmuto/review/issues/433

# Version 1.5.0の主な変更点

## 注意
* 後述するリストハイライト時の言語指定のため、``//list``、``//emlist``等のリストブロック記法をreview-ext.rbで拡張している場合、既存のコードにエラーが出ることがあります。その場合、review-ext.rbを修正する必要があります（review-ext.rbを使っていない場合は影響はありません）。

## 全般
* config.ymlに設定項目を追加しました。
* ``@<hd>``で付録の表記を正しく参照できるようにしました。
* 浅いレベルのコラムを参照できない問題を修正しました。
* i18n.ymlの項目を追加しました。
* ``ReVIEW::Book::Base.load_default``を廃止しました。
* ``@<imgref>``記法を追加しました。
* サンプルのRakefileにpdf/epub/cleanタスクを追加しました。
* ドキュメントのフォーマットをRDocからMarkdownに変更しました。
* 「Re:VIEW Quick Start Guide」を追加しました。
* ``@<hd>``でidが一意なターゲットを指定するときに``|``を省略できるようにしました。
* リストのハイライト表示のときに言語を指定できるようにしました。
* 「Re:VIEW Format Guide」を追加しました。
* ハイライトを使うときのconfig.ymlの設定名として``highlight``を追加しました。

## コマンド
### review-epubmaker
* config.ymlの``toc``をサポートしました。

### review-init
* ディレクトリが存在しているときでも実行できる``--force``オプションを追加しました。

### review-vol
* ``--yaml``オプションを追加しました。

## Builders and Makers
### markdownbuilder
* ``list_header()``と``list_body()``を追加しました。

### htmlbuilder
* ``HTMLBuilder#texequation``のMathMLのエラーを修正しました。

### idgxmlbuilder
* ``@<ttb>``の``index``タグを廃止しました。

### latexbuilder
* ``@<table>``で他の章のテーブルを参照できるようにしました。
* listings packageによるハイライトをサポートしました。

### pdfmaker
* LaTeXツールがないときにエラーを出すようにしました。
* config.ymlの``toctitle``をサポートしました。
* すでにPDFファイルが存在しているときに削除するようにしました。
* config.ymlの``dvicommand``と``dvioptions``をサポートしました。
* config.ymlの``texoptions``をサポートしました。
* ``sty/*.fd``や``sty/*.cls``を読み込むようにしました。
* TeXの処理フックを追加しました。
* LaTeXコマンドの失敗時に例外を上げて処理が止まるようにしました
* 一部sedコマンドを利用していた部分を修正し依存しないようにしました。

### epubmaker
* MathMLのサポートを改善しました。
* ダミーの``<li>``要素を見せないようにしました。
* config.ymlにツリー構造を導入しました。
* 国際化のリソースとしてEPUBMaker::Resourceの代わりにReVIEW::I18nが使われるようになりました。

## コードコントリビュータ
* akinomurasameさん
* gfxさん
* krororoさん
* orangainさん


# Version 1.4.0の主な変更点
## 全般
* bib記法のIDを正規化しました。
* POSTDEFファイルとcatalog.ymlのPOSTDEFセクションの挙動を合わせました。
* catalog.ymlにAPPENDIXセクションを追加しました。
* 暗黙的なprefaces, appendix, postscriptsの指定を削除しました。
* コードとテストケースをリファクタリングしました。
* README.rdocにInstallation, Resources, Linksの情報を追加しました。

## コマンド
### review-epubmaker
* debugがtrueのときに、第一階層の一時ディレクトリを保持するようにしました。
* cover_linearオプションをサポートしました。

### review-catalog-converter
* 従来のカタログファイルをcatalog.ymlに変換するコマンドを追加しました。

## Builders and Makers
### markdownbuilder
* GitHub Flavored Markdownとの互換性を向上させました。
* Headlineの前後にブランクを挿入しました。
* tt記法を追加しました。
* footnote記法を追加しました。
* indepimage記法を追加しました。
* 表示されていなかった画像のキャプションを表示するようにしました。

### htmlbuilder
* 画像ファイルが見つからないときに警告を出すようにしました。
* レイアウトファイル名を'layout.erb'から'layout.html.erb'に変更しました。
* emlist/emlistnum/cmdのキャプションをコンパイルするようにしました。
* title記法をコンパイルするようにしました。

### idgxmlbuilder
* 画像ファイルが見つからないときに警告を出すようにしました。

### latexbuilder
* レイアウトファイル名を'review.tex.erb'から'layout.tex.erb'に変更しました。
* 奥付用の項目として'contact'(連絡先)を追加しました。また、発行所と印刷所を両方併記するため、pblを「発行所」として追加し、prtを「印刷所」として両方を記述できるようにしました。
  ただし、互換性のためにデフォルトではprtは「発行所」になっているため、i18n.ymlで設定を行う必要があります。


### pdfmaker
* ロケールファイルを使用できるようにしました。
* colophon_orderオプションを追加しました。

### epubmaker
* EPUB3のときのカバーファイルにepub:type='cover'属性を追加しました。
* 見出し含まれるHTMLの特殊文字をエスケープしました。

## コードコントリビュータ
* suzuki さん
* vvakame さん
* eiel さん



# Version 1.3.0の主な変更点

## 全般
* 従来のカタログファイルの代わりにcatalog.ymlを使用できるようにしました。
* コラムを参照する`@<column>{}`を追加しました。
* `@<chapref>{}`で部を参照できるようにしました。
* セーフモード（環境変数`REVIEW_SAFE_MODE`の設定）を追加しました。
* *.reのファイルは必ずカタログファイルと同じ階層に置くことにしました。
* config.rbを使った設定を廃止しました。
* 文書ディレクトリ内にあるlib/review/以下のファイルの読み込み機能を廃止しました。
* 付録の見出し表記を指定する設定`appendix_format`（arabic, roman, alphaのいずれかを指定）を追加しました。

## コマンド
* 同じバージョンのreview-compileを使用するようにしました。
* バージョン情報を表示する`--version`オプションを追加しました。

### review-compile
* カタログファイルを指定する`--catalogfile`オプションを追加しました。

### review-pdfmaker
* ビルド用の一時ディレクトリを削除するようにしました。
* 途中でエラーが発生した場合に動作を停止するようにしました。
* 途中でエラーが発生しても停止せずに実行し続ける`--ignore-errors`オプションを追加しました。
* ディレクトリの深い場所にある画像ファイルのebb/bbファイルを作成するようにしました。
* `debug`オプションを上書きする`--[no-]debug`オプションを追加しました。

### review-init
* 出力されるCSSのファイル名を統一しました。

### review-epubmaker
* review-empumaker-ngから名称を変更しました。旧review-epubmakerはreview-epubmaker-legacyに名称を変更しました。
* EPUBに同梱する画像の指定に関する`verify_target_images`と`force_include_images`オプションを追加しました。

## Builders

### htmlbuilder
* 脚注から参照元の本文に戻れるようにしました。
* HTMLコメント内でハイフンのエスケープをするようにしました。
* id属性をHTML規格に合わせて正規化するようにしました。
* layoutファイルからセクションタイトル一覧（`toc`）を参照できるようにしました。
* layoutファイルから前後の章のリンク（`prev_chapter`, `next_chapter`）を参照できるようにしました。

### latexbuilder
* コラムを目次に含めるようにしました。
* graph記法で使用する画像の形式をPDFに変更しました。

## コードコントリビュータ
* kazutomi さん
* dmiyakawa さん
* zunda さん

# Version 1.2.0の主な変更点

## 全般

* 名称が'ReVIEW'から'Re:VIEW'に変更になりました。
* 画像ファイルが設定ではなくビルダ名などを元にディレクトリ内を探索するようになりました。

## コマンド
### review-epubmaker-ng / review-epubmaker

* フォント埋め込みに対応しました。
* EPUB3のMathMLに対応しました。
* OPFファイル内のIDとして'rv-'というプレフィックスをつけるようになりました。
* config.ymlでpht(Photographer / 撮影者) と csl(Consultant / 監修者)を指定できるようになりました。
* 目次の各章・節見出し等について、元々の見出しにHTMLの装飾要素がついていた場合、目次ではそれらの要素を落とすようにしました(review-epubmaker)

### review-pdfmaker

* config.ymlで"texcommand"を指定できるようになりました。これにより、platexではなくLuaLaTeX等も指定できるようになりました。

### review-init

* gemでインストールした場合に動作しないバグを修正しました。

## Builders

### HTMLBuilder

* pygmentsによるhiglightingをconfig.ymlで"pygments: true"と指定した場合のみ有効になるようにしました。
* EPUB3での脚注について、epub:type="noteref"とepub:type="footnote"が指定されるようになりました。

### LATEXBuilder

* //bibpaper の直後で改行するようにしました。

### MARKDOWNBuilder

* ``@<em>{}`` (``@<i>``と同様)と``@<strong>{}``(``@<b>``と同様)をサポートしました。



# Version 1.1の変更点

## 全般

* markdownbuilder追加
* inaobuilder追加
* jewelerからbundlerに変更
* review-initコマンドを追加
* プリプロセスでMIMEと半角カナを保持するよう修正
* エスケープされるべきところでされないバグを修正(``[...]``内で「``]``」がエスケープできない等)
* その他多数のバグ修正

## review-compile

* --structuredxmlオプション追加(idgxml)
* --toclevelオプション追加
* --tabwidthオプション追加
* --output-fileオプション追加

## review-epubmakerとreview-pdfmaker共通

* PARTファイルの中に``foo.re``といったファイル名を書けるよう修正
* 一時ファイルのファイル名を変更(文書名+"-pdf" or 文書名+"-epub")

## review-epubmaker
* epubversion、htmlversion追加(EPUB3は実験的サポート)
* YAMLファイルにcover_linearオプション追加

## review-pdfmaker
* review.tex.erbファイル追加
* HTMLbuilderのようにlayoutsファイルをサポート

## review-compile

* ``//centering``記法追加
* ``//olnum``記法追加
* ``//comment``の引数を0..1に変更
* ``//source``の引数を0..1に変更

## htmlbuilder

* HTML5には``<tt>``がないので``<code>``に変更
* ``@<bou>``を追加
* pygmentsによるhighlightをサポート
* ``<title>``内ではReVIEWのタグを無視するよう修正

## latexbuilder
* ReVIEW専用マクロを追加(``\reviewindepimagecaption``, ``\reviewth``, ``\reviewem`` and ``\reviewstrong``)
* ``\reviewbibref``、``\\reviewtableref``、``\reviewimageref``マクロに引数を追加してリンクになるよう修正
* デフォルトのテンプレートに``\usepackage{amsmath}``を追加
* ``//box``記法をサポート
* ``@<ami>``記法をサポート
* 見出しレベル5と6を追加(paragraph, subparagraph)
* ダッシュのエスケープを追加
* ``begin{alltt}..\end{alltt}``は``\reviewemlist``、``\reviewlist``、``\reviewcmd``の各専用マクロ内で指定するよう(自分で再定義できるよう)修正
