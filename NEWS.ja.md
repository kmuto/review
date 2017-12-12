# Version 2.4.0

## 新機能

* エラーや警告の出力に Ruby 標準の Logger クラスを使うようにしました ([#705])
* EPUBMaker: 電子書籍ストアで拒絶されることの多い、大きなピクセル数の画像ファイルに対して警告を出すようにしました ([#819])
* LATEXBuilder: ページ参照のための `@<pageref>` 命令を追加しました ([#836])
* インライン命令で `{}` で引数を囲む代わりに `| |` あるいは `$ $` で囲むことにより、`}` のエスケープが不要になる、フェンス記法を導入しました ([#876])

## 非互換の変更

* LATEXBuilder: 部番号のデフォルト表記をローマ数字にしました ([#837])
* EPUBMaker: 目次を冒頭ではなく前付の後に置くようにしました ([#840])
* `imgmath` 有効時に数式画像ファイルを書き出すフォルダを、`images` 直下ではなく `images/_review_math`  としました ([#856])
* EPUBMaker: 大扉の有無を示す titlepage のデフォルトは null (無) から、PDFMaker と同様に true (有) になりました ([#862])
* EPUBMaker: テンプレートファイルの `params` を `config` に置き換えました ([#867])
* 利用者がいないため、EWBBuilder を撤去しました ([#828])

## バグ修正

* 見出しが空、あるいはコードブロック内等で誤認識される挙動を修正しました ([#121])
* TOPBuilder: `//image` で metric パラメータが無視されるのを修正しました。`//indepimage` で metric パラメータがないとエラーになるのを修正しました ([#805])
* 他章のコラム参照が動作していなかったのを修正しました ([#817])
* config.yml で `date` の値が空のときに実行時の日付が正しく入るようにしました ([#824])
* 前付・後付の図・表・リストのキャプションの見出しの前置文字列の定義の誤りを修正しました ([#830])
* WebMaker の書籍見出しに名前付きパラメータを与えたときの挙動を修正しました ([#831])
* フォントファイルが不足した一部の環境において、欧文が Type3 形式になってしまう問題を避けるため、lmodern スタイルファイルを読み込むようにしました ([#843])
* config.yml で `/` を含む見出しがおかしくなる問題を修正しました ([#852])
* PDFMaker において toclevel の値が正しい効果を表すように修正しました ([#846])

## 機能強化

* `//indepimage` で `{ 〜 //}` によるブロック表記を許容するようになりました ([#802])
* `//indepimage` で画像ファイルが見つからないときに警告を出すようにしました ([#803])
* LATEXBuilder: `//source` はキャプション引数を許容するようになりました ([#834])

## ドキュメント

* `rake pdf` には LaTeX 環境が必要なことを追記しました ([#800])
* README.md 内のリンクミスを修正しました ([#815])
* Re:VIEW の各命令の登場パターンを網羅するテストドキュメントを用意しました ([#833])
* config.yml の titlepage パラメータのコメントを修正しました ([#847])
* footnotetext の説明を修正しました ([#872])

## その他

* rubocop 0.50.0 の指摘に基づき、コーディングルールを統一しました ([#823])

## コントリビューターのみなさん
* [@ryota-murakami](https://github.com/ryota-murakami)
* [@nasum](https://github.com/nasum)
* [@kokuyouwind](https://github.com/kokuyouwind)

[#121]: https://github.com/kmuto/review/issues/121
[#705]: https://github.com/kmuto/review/issues/705
[#800]: https://github.com/kmuto/review/pull/800
[#802]: https://github.com/kmuto/review/issues/802
[#803]: https://github.com/kmuto/review/issues/803
[#805]: https://github.com/kmuto/review/pull/805
[#815]: https://github.com/kmuto/review/pull/815
[#817]: https://github.com/kmuto/review/pull/817
[#819]: https://github.com/kmuto/review/issues/819
[#823]: https://github.com/kmuto/review/issues/823
[#824]: https://github.com/kmuto/review/issues/824
[#828]: https://github.com/kmuto/review/pull/828
[#830]: https://github.com/kmuto/review/pull/830
[#831]: https://github.com/kmuto/review/pull/831
[#833]: https://github.com/kmuto/review/pull/833
[#834]: https://github.com/kmuto/review/issues/834
[#836]: https://github.com/kmuto/review/issues/836
[#840]: https://github.com/kmuto/review/pull/840
[#843]: https://github.com/kmuto/review/issues/843
[#837]: https://github.com/kmuto/review/issues/837
[#846]: https://github.com/kmuto/review/issues/846
[#847]: https://github.com/kmuto/review/pull/847
[#852]: https://github.com/kmuto/review/issues/852
[#856]: https://github.com/kmuto/review/issues/856
[#862]: https://github.com/kmuto/review/pull/862
[#867]: https://github.com/kmuto/review/issues/867
[#872]: https://github.com/kmuto/review/issues/872
[#876]: https://github.com/kmuto/review/issues/876

# Version 2.3.0

## 新機能

* 連番がつかない表 `//emtable` を追加しました ([#777]) ([#787])
* EPUBMaker: 数式を画像にするオプション `imgmath` を追加しました ([#773]) ([#774])
* HTMLBuilder: 数式を画像にできるようにしました ([#774])

## バグ修正

* LATEXBuilder: appendix内でのキャプションの章番号を修正しました ([#766])
* `//imgtable`を使った際、表の連番カウントがずれる問題を修正しました ([#782])
* 用語リストの直後に箇条書きを使った場合の不具合を修正しました ([#794])([#795])

## 機能強化

* `doc/config.yml.sample`のbackcoverの説明を修正しました ([#765])([#767])
* 部(part)ファイル内で見出しや図表リストへの参照の接頭辞を修正しました ([#779])
* LATEXBuilder: LaTeX内で使用できる画像フォーマットの設定を修正しました ([#785])

## ドキュメント

* `//embed` の説明を NEWS.ja.md にも追加しました
* `doc/NEWS.*`をトップレベルに移動しました ([#780])
* 他の章の図表の参照方法を追記しました ([#770]) ([#771])
* `//table`記法の説明を修正しました ([#776])
* gitレポジトリのURLに https: ではなく git: を使うよう修正しました ([#778])
* ChangeLogをアーカイブしました。今後はgit logをお使いください ([#784]) ([#788])

## その他

* `.rubocop.yml` の警告を抑制しました

## コントリビューターのみなさん

* [@karino2](https://github.com/karino2)
* [@imamurayusuke](https://github.com/imamurayusuke)
* [@znz](https://github.com/znz)
* [@hanachin](https://github.com/hanachin)

[#765]: https://github.com/kmuto/review/issues/765
[#766]: https://github.com/kmuto/review/issues/766
[#767]: https://github.com/kmuto/review/issues/767
[#770]: https://github.com/kmuto/review/issues/770
[#771]: https://github.com/kmuto/review/issues/771
[#773]: https://github.com/kmuto/review/issues/773
[#774]: https://github.com/kmuto/review/issues/774
[#776]: https://github.com/kmuto/review/issues/776
[#777]: https://github.com/kmuto/review/issues/777
[#778]: https://github.com/kmuto/review/issues/778
[#779]: https://github.com/kmuto/review/issues/779
[#780]: https://github.com/kmuto/review/issues/780
[#782]: https://github.com/kmuto/review/issues/782
[#784]: https://github.com/kmuto/review/issues/784
[#785]: https://github.com/kmuto/review/issues/785
[#787]: https://github.com/kmuto/review/issues/787
[#788]: https://github.com/kmuto/review/issues/788
[#795]: https://github.com/kmuto/review/issues/795


# Version 2.2.0

## 新機能

* PDFMaker: 索引`@<idx>`, `@<hidx>`をサポートしました ([#261],[#660],[#669],[#740])
* RSTBuilder を追加しました ([#733],[#738])
* 直接埋め込み用の `//embed{...//}` と `@<embed>{...}` を追加しました ([#730],[#751],[#757],[#758])
* HTMLBuilder, IDGXMLBuilder, LATEXBuilder:  `//listnum` と `//emlistnum` で使える `//firstlinenum` コマンドを追加しました([#685],[#688])
* review-compile: `--nolfinxml` は不要になりました ([#683],[#708])
* HTMLBuilder: 参照用インライン (`@<img>`, `@<table>`, `@<list>`) を `<span>`で囲うようにしました. class属性は 'imgref', 'tableref', 'listref'です. ([#696],[#697])
* HTMLBuilder: コードハイライト用ライブラリとしてRougeをサポートするようにしました ([#684],[#710],[#711])

## 非互換の変更

* LATEXBuilder: `//source`の生成するマクロを修正しました ([#681])
* インライン内でのエスケープのルールのバグを修正しました ([#731])
    * `\}` -> `}`
    * `\\` -> `\`
    * `\x` -> `\x` (`x` != `\`かつ`x` != `}`の場合)

## バグ修正

* draftモードでのコメント機能を整理しました ([#360],[#717])
* i18n機能の引数の数が想定と異なっている場合の挙動を修正しました ([#667],[#723])
* support builder option for `//tsize` and `//latextsize` ([#716],[#719],[#720])
* html, idgxml, markdownでのul_item() メソッドを削除しました. ([#726],[#727])
* PDFMaker: 設定ファイルのimagedirの値を反映するようにしました ([#756],[#759])
* HTMLBuilder, LATEXBuilder, IDGXMLBuilder: コラム内での引数のインラインを処理するようにしました
* review-init: エンコーディングを正しく指定するようにしました. ([#761])
* EPUBMaker, PDFMaker: PDFとEPUBのsubtitleを修正しました ([#742],[#745],[#747])
* TOPBuilder: `@<list>`のリンク切れを修正しました ([#763])

## 機能強化

* LATEXBuilder: jumoline.styを有効にしました
* IDGXMLBuilder, HTMLBuilder: エラーや警告が生成された文書内に出力されないようにしました ([#706],[#753])
* image_finder.rb: シンボリックリンクのディレクトリにも対応するようにしました ([#743])
* TOPBuilder: 見出しの処理を修正しました ([#729])
* 設定ファイルでのhistoryの日付をフリーフォーマットでも対応するようにしました ([#693])
* HTMLBuilder: リストのid属性を出力するようにしました ([#724])
* rubyzipがない場合、zipのテストをスキップするようにしました ([#713],[#714])
* convertコマンドがない場合のテストを修正しました ([#712],[#718])
* TOPBuilder: `@<bib>` と `//bibpaper` に対応しました ([#763])
* TOPBuilder: `[notoc]` と `[nodisp]` に対応しました ([#763])


## ドキュメント

* 索引用のドキュメント makeindex.(ja.)md を追加しました

## その他

* rubocopの設定を見直して警告の抑制をしました

## コントリビューターのみなさん

* [@kuroda](https://github.com/kuroda)
* [@olleolleolle](https://github.com/olleolleolle)
* [@shirou](https://github.com/shirou)
* [@m-shibata](https://github.com/m-shibata)
* [@kenkiku1021](https://github.com/kenkiku1021)

[#261]: https://github.com/kmuto/review/issues/261
[#360]: https://github.com/kmuto/review/issues/360
[#660]: https://github.com/kmuto/review/issues/660
[#667]: https://github.com/kmuto/review/issues/667
[#669]: https://github.com/kmuto/review/issues/669
[#681]: https://github.com/kmuto/review/issues/681
[#682]: https://github.com/kmuto/review/issues/682
[#683]: https://github.com/kmuto/review/issues/683
[#684]: https://github.com/kmuto/review/issues/684
[#685]: https://github.com/kmuto/review/issues/685
[#686]: https://github.com/kmuto/review/issues/686
[#688]: https://github.com/kmuto/review/issues/688
[#693]: https://github.com/kmuto/review/issues/693
[#696]: https://github.com/kmuto/review/issues/696
[#697]: https://github.com/kmuto/review/issues/697
[#706]: https://github.com/kmuto/review/issues/706
[#708]: https://github.com/kmuto/review/issues/708
[#710]: https://github.com/kmuto/review/issues/710
[#711]: https://github.com/kmuto/review/issues/711
[#712]: https://github.com/kmuto/review/issues/712
[#713]: https://github.com/kmuto/review/issues/713
[#714]: https://github.com/kmuto/review/issues/714
[#716]: https://github.com/kmuto/review/issues/716
[#717]: https://github.com/kmuto/review/issues/717
[#718]: https://github.com/kmuto/review/issues/718
[#719]: https://github.com/kmuto/review/issues/719
[#720]: https://github.com/kmuto/review/issues/720
[#723]: https://github.com/kmuto/review/issues/723
[#724]: https://github.com/kmuto/review/issues/724
[#726]: https://github.com/kmuto/review/issues/726
[#727]: https://github.com/kmuto/review/issues/727
[#729]: https://github.com/kmuto/review/issues/729
[#730]: https://github.com/kmuto/review/issues/730
[#731]: https://github.com/kmuto/review/issues/731
[#733]: https://github.com/kmuto/review/issues/733
[#738]: https://github.com/kmuto/review/issues/738
[#740]: https://github.com/kmuto/review/issues/740
[#742]: https://github.com/kmuto/review/issues/742
[#743]: https://github.com/kmuto/review/issues/743
[#745]: https://github.com/kmuto/review/issues/745
[#747]: https://github.com/kmuto/review/issues/747
[#751]: https://github.com/kmuto/review/issues/751
[#753]: https://github.com/kmuto/review/issues/753
[#756]: https://github.com/kmuto/review/issues/756
[#757]: https://github.com/kmuto/review/issues/757
[#758]: https://github.com/kmuto/review/issues/758
[#759]: https://github.com/kmuto/review/issues/759
[#761]: https://github.com/kmuto/review/issues/761
[#763]: https://github.com/kmuto/review/issues/763


# Version 2.1.0 の主な変更点

## 新機能

* review-init: Gemfileを生成するようにしました([#650])
* HTMLBuilder: リスト内で言語別のclassを生成するようにしました([#666])
* HTMLBuilder: image同様indepimageでも<div>要素にid属性を追加しました
* MD2INAOBuilder: 新builderとしてMD2INAOBuilderを追加しました ([#671])
* MARKDOWNBuilder, MD2INAOBuilder: ルビに対応しました ([#671])
* TEXTBuilder: `@<hd>`に対応しました([#648])
* TOPBuilder: `@<comment>{}`に対応しました ([#625], [#627])

## 非互換の変更

## バグ修正

* review-validate: ブロックや表内でのコメントの挙動と、メッセージを修正しました
* LATEXBuilder: config.ymlで`rights`が空の場合に対応しました ([#653])
* LATEXBuilder: config.ymlとlocale.ymlの値のエスケープを修正しました ([#642])
* PDFMaker: AI, EPS, TIFFの画像に対応しました ([#675])
* PDFMaker: フックからフルパスを取得できるよう @basehookdir を追加しました ([#662])
* EPUBMaker: dc:identifierが空になってしまうバグを修正しました ([#636])
* EPUBMaker: coverファイルの拡張子がxhtmlになってしまうバグを修正しました ([#618])
* WEBMaker: リンクを修正しました ([#645])
* WEBMaker: 部がファイルでない場合のリンクを修正しました ([#639], [#641])
* I18n: format_number_headerので`%pJ`の扱いを修正しました ([#628])

## 機能強化

* LATEXBuilder: pLaTeXでもpxjahyper packageを使うようにしました([#640])
* LATEXBuilder: `layout.tex.erb`を改良しました([#617])
* LATEXBuilder: locale.ymlで指定されたキーワードを使うようにしました ([#629])
* IDGXMLBuilder: コラムの埋め込み目次情報のXMLインストラクションを修正しました ([#634])
* IDGXMLBuilder: //emlistで空のcaptionができるバグを修正しました ([#633])
* Rakefile: `preproc`タスクを追加しました ([#630])

## ドキュメント

* 「EPUBローカルルールへの対応方法」のドキュメントを英訳しました
* 「review-preprocユーザガイド(preproc(.ja).md)」を追加しました ([#632])
* config.yml: `csl`の例を追加しました
* config.yml: シンプルなサンプルファイル(config.yml.sample-simple)を追加しました ([#626])

## その他

* templates/以下のテンプレートファイルのライセンスを他の文書内に取り込みやすくするため、MIT licenseにしました([#663])
* rubocopの新しい警告を抑制しました

## コントリビューターのみなさん

* [@kazken3](https://github.com/kazken3)
* [@vvakame](https://github.com/vvakame)
* [@masarakki](https://github.com/masarakki)
* [@munepi](https://github.com/munepi)
* [@znz](https://github.com/znz)

[#675]: https://github.com/kmuto/review/issues/675
[#671]: https://github.com/kmuto/review/issues/671
[#666]: https://github.com/kmuto/review/issues/666
[#663]: https://github.com/kmuto/review/issues/663
[#662]: https://github.com/kmuto/review/issues/662
[#653]: https://github.com/kmuto/review/issues/653
[#650]: https://github.com/kmuto/review/issues/650
[#648]: https://github.com/kmuto/review/issues/648
[#645]: https://github.com/kmuto/review/issues/645
[#642]: https://github.com/kmuto/review/issues/642
[#641]: https://github.com/kmuto/review/issues/641
[#640]: https://github.com/kmuto/review/issues/640
[#638]: https://github.com/kmuto/review/issues/638
[#636]: https://github.com/kmuto/review/issues/636
[#634]: https://github.com/kmuto/review/issues/634
[#633]: https://github.com/kmuto/review/issues/633
[#632]: https://github.com/kmuto/review/issues/632
[#630]: https://github.com/kmuto/review/issues/630
[#629]: https://github.com/kmuto/review/issues/629
[#628]: https://github.com/kmuto/review/issues/628
[#627]: https://github.com/kmuto/review/issues/627
[#626]: https://github.com/kmuto/review/issues/626
[#625]: https://github.com/kmuto/review/issues/625
[#618]: https://github.com/kmuto/review/issues/618
[#617]: https://github.com/kmuto/review/issues/617

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
