# Version 2.1.0の主な変更点

* config.ymlの``makeindexcommand``と``makeindexoptions``をサポートしました。

# Version 2.0.0の主な変更点

## 新機能
* デフォルトで `./config.yml` を読み込むようにしました ([#477], [#479])
* config.yml: `review_version` を追加しました([#276], [#539], [#545])
   * review_versionをnilにすると警告が表示されません ([#592])
* 実験的に縦書き機能をサポートしました ([#563])
* ヘッダ部分に`[notoc]` と `[nodisp]` を使えるようにしました ([#506], [#555])
* `@<column>` と `@<hd>` で他の章にあるコラムを参照可能にしました ([#333], [#476])
* `//imgtable` コマンドを追加しました ([#499])
* 設定ファイルのショートカットキーを使えるようにしました ([#540])
    * たとえば、epubmaker使用時に `@config["epubmaker"]["foo"]` の代わりに `@config["foo"]` が使えます
* `inherit` を使って、複数の設定ファイルを読み込み可能にしました ([#511], [#528])
* i18nのフォーマットを追加しました ([#520])
* `rake` でテストとrubocopを実行するようにしました ([#587])
* webmakerを追加しました ([#498])
* LATEXBuilder: `image_scale2width` オプションを追加しました ([#543])
* PDFMaker: platex から uplatex に移行しました ([#541])
* EPUBMaker: 電子協ガイドフォーマットをサポートしました ([#251], [#429])
* EPUBMaker: `direction` をデフォルトの設定に追加しました ([#508])
* EPUBMaker: 書籍タイトルや著者の「読み」を追加しました ([#507])
* review-preproc: 拡張可能にました ([#494])
* HTMLBuilder: config.yml で epubmaker/externallink: false を設定すると、`@<href>` のハイパーリンクを無効にできるようにしました ([#509], [#544])
* EPUBMaker: OPFにカスタムプレフィックスと `<meta>` 要素を追加しました ([#513])
* PDFMaker: 設定ファイルで `history` をサポートしました ([#566])

## 非互換の変更
* デフォルトの`epubversion` と `htmlversion` を更新しました ([#542])
* 'param' の後方互換性を廃止しました ([#594])
* config.ymlの'pygments:' を廃止しました ([#604])
* その他、後方互換性を廃止しました ([#560])
    * layout.erb -> layout.html.erb
    * locale.yaml -> locale.yml
    * PageMetric.a5 -> PageMetric::A5
    * locale.yaml や layout.erb を使っているとエラーになります
    * `prt` は `発行所` ではなく `印刷所` になります. `発行所` は `pbl` です.([#562, #593])
* `appendix_format` を廃止しました ([#609])
* inaobuilder を廃止しました (アップストリームで修正Markdownを使用することになったため) ([#573])
* 古い epubmaker を削除しました
* review-compile: `-a/--all` オプションを廃止しました ([#481])

## バグ修正
* HTMLのエスケープ処理漏れに対応しました ([#589], [#591])
* review-epubmaker: すべての画像をコピーするように修正しました ([#224])
* ``[nonum]`` に関連するバグを修正しました ([#301], [#436], [#506], [#550], [#554], [#555])
* IDGXMLBuilder: テーブルセルの幅における pt と mm の計算を修正しました ([#558])
* HTMLBuilder: `//image[scale=XXX]` で `width` の代わりに `class` を使うようにして、epubcheckのテストを通るようにしました ([#482], [#372])

## リファクタリング
* EPUBmaker/PDFmakerで名前付きパラメータへを対応しました ([#534])
* `ReVIEW::YAMLLoader` を追加しました ([#518])
* いくつかのグローバル変数を削除しました ([#240])
* テストのwarningを無効にしました ([#597])
* いくつかのwarningに対応しました (circular require, unused variable, redefining methods, too many args) ([#599], [#601])
* MakerHelper: class -> module ([#582])
* review-init: config.yml を doc/config.yml.sample から生成するようにしました ([#580])
* ReVIEW::Template にテンプレートエンジンを統合しました ([#576])
  * HTMLBuilder: HTMLLayout を削除しました
  * LATEXBuilder: テンプレートでインスタンス変数を使うようにしました ([#598])
  * LATEXBuilder: move lib/review/layout.tex.erb to templates/latex/ ([#572])
* config.yml.sample を更新しました ([#579])
* テストから1.8と1.9.3のコードを削除しました(Travis向け) ([#577])
* LaTeX のテンプレートを修正しました ([#575])
* ファイルを開くときに BOM|utf-8 フラグを使用するようにしました ([#574])
* review-preproc: default_external を UTF-8 に設定しました ([#486])
* デバッグ時の pdf と epub の build_path を修正しました ([#564], [#556])
* EPUBMakerをリファクタリングしました ([#533])
* ruby-uuidの代わりにSecureRandom.uuidを使うようにしました ([#497])
* epubmaker, pdfmaker: system() の代わりに ReVIEW::Converter を使うようにしました ([#493])
* zipコマンドの代わりにRubyのZipライブラリを使うようにしました ([#487])
* review-index: TOCParser と TOCPrinter を洗練させました ([#486])
* 廃止済みのパラメータを削除して、デフォルト値を変更しました ([#547])
* サンプルファイル config.yml の名前を config.yml.* に変更しました ([#538])
* `Hash#deep_merge` を追加しました ([#523])
* LATEXBuilder: `\Underline` の代わりに `\reviewunderline` を使うようにしました ([#408])
* Configureクラスで 'name' の値を取得できるように `name_of` と `names_of` メソッドを追加しました ([#534])
* EPUBMaker: colophon_order の場所を変更しました ([#460])
* TOCPrinter: IDGTOCPrinter を削除しました ([#486])
* Book#catalog=(catalog) と Catalog.new(obj) を追加しました ([93691d0e2601eeb5715714b4fb92840bb3b3ff8b])
* Chapter, Part: 遅延読み込みしないようにしました ([#491])

## ドキュメント
* README: rdoc -> md ([#610])
* format.md, quickstart.md を更新しました
* 縦書きとPDFMakerについて説明を追加しました
* 英語版のドキュメントを修正しました ([#588])

## コードコントリビュータ
* [@arikui1911](https://github.com/arikui1911)

[#224]: https://github.com/kmuto/review/issues/224
[#240]: https://github.com/kmuto/review/issues/240
[#251]: https://github.com/kmuto/review/issues/251
[#276]: https://github.com/kmuto/review/issues/276
[#301]: https://github.com/kmuto/review/issues/301
[#333]: https://github.com/kmuto/review/issues/333
[#372]: https://github.com/kmuto/review/issues/372
[#408]: https://github.com/kmuto/review/issues/408
[#429]: https://github.com/kmuto/review/issues/429
[#436]: https://github.com/kmuto/review/issues/436
[#460]: https://github.com/kmuto/review/issues/460
[#476]: https://github.com/kmuto/review/issues/476
[#477]: https://github.com/kmuto/review/issues/477
[#479]: https://github.com/kmuto/review/issues/479
[#481]: https://github.com/kmuto/review/issues/481
[#482]: https://github.com/kmuto/review/issues/482
[#486]: https://github.com/kmuto/review/issues/486
[#487]: https://github.com/kmuto/review/issues/487
[#491]: https://github.com/kmuto/review/issues/491
[#493]: https://github.com/kmuto/review/issues/493
[#494]: https://github.com/kmuto/review/issues/494
[#497]: https://github.com/kmuto/review/issues/497
[#498]: https://github.com/kmuto/review/issues/498
[#499]: https://github.com/kmuto/review/issues/499
[#506]: https://github.com/kmuto/review/issues/506
[#507]: https://github.com/kmuto/review/issues/507
[#508]: https://github.com/kmuto/review/issues/508
[#509]: https://github.com/kmuto/review/issues/509
[#511]: https://github.com/kmuto/review/issues/511
[#513]: https://github.com/kmuto/review/issues/513
[#518]: https://github.com/kmuto/review/issues/518
[#520]: https://github.com/kmuto/review/issues/520
[#523]: https://github.com/kmuto/review/issues/523
[#528]: https://github.com/kmuto/review/issues/528
[#533]: https://github.com/kmuto/review/issues/533
[#534]: https://github.com/kmuto/review/issues/534
[#538]: https://github.com/kmuto/review/issues/538
[#539]: https://github.com/kmuto/review/issues/539
[#540]: https://github.com/kmuto/review/issues/540
[#541]: https://github.com/kmuto/review/issues/541
[#542]: https://github.com/kmuto/review/issues/542
[#543]: https://github.com/kmuto/review/issues/543
[#544]: https://github.com/kmuto/review/issues/544
[#545]: https://github.com/kmuto/review/issues/545
[#547]: https://github.com/kmuto/review/issues/547
[#550]: https://github.com/kmuto/review/issues/550
[#554]: https://github.com/kmuto/review/issues/554
[#555]: https://github.com/kmuto/review/issues/555
[#556]: https://github.com/kmuto/review/issues/556
[#557]: https://github.com/kmuto/review/issues/557
[#558]: https://github.com/kmuto/review/issues/558
[#560]: https://github.com/kmuto/review/issues/560
[#562]: https://github.com/kmuto/review/issues/562
[#563]: https://github.com/kmuto/review/issues/563
[#564]: https://github.com/kmuto/review/issues/564
[#566]: https://github.com/kmuto/review/issues/566
[#572]: https://github.com/kmuto/review/issues/572
[#573]: https://github.com/kmuto/review/issues/573
[#574]: https://github.com/kmuto/review/issues/574
[#575]: https://github.com/kmuto/review/issues/575
[#576]: https://github.com/kmuto/review/issues/576
[#577]: https://github.com/kmuto/review/issues/577
[#579]: https://github.com/kmuto/review/issues/579
[#580]: https://github.com/kmuto/review/issues/580
[#582]: https://github.com/kmuto/review/issues/582
[#587]: https://github.com/kmuto/review/issues/587
[#588]: https://github.com/kmuto/review/issues/588
[#589]: https://github.com/kmuto/review/issues/589
[#591]: https://github.com/kmuto/review/issues/591
[#592]: https://github.com/kmuto/review/issues/592
[#593]: https://github.com/kmuto/review/issues/593
[#594]: https://github.com/kmuto/review/issues/594
[#597]: https://github.com/kmuto/review/issues/597
[#598]: https://github.com/kmuto/review/issues/598
[#599]: https://github.com/kmuto/review/issues/599
[#601]: https://github.com/kmuto/review/issues/601
[#604]: https://github.com/kmuto/review/issues/604
[#609]: https://github.com/kmuto/review/issues/609
[#610]: https://github.com/kmuto/review/issues/610
[93691d0e2601eeb5715714b4fb92840bb3b3ff8b]: https://github.com/kmuto/review/commit/93691d0e2601eeb5715714b4fb92840bb3b3ff8b
[67014a65411e3a3e5e2c57c57e01bee1ad18efc6]: https://github.com/kmuto/review/commit/67014a65411e3a3e5e2c57c57e01bee1ad18efc6

# Version 1.7.2の主な変更点

## バグ修正
* latexbuilderで`//list`がhighlitingなしのときにキャプションが表示されなくなっていたのを修正しました ([#465])
* markdownbuilderでdefinition listを使うとエラーになるのを修正しました ([#473])

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
