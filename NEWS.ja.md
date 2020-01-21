# Version 4.1.0
## 新機能
* 表のセル区切りの文字を `table_row_separator` パラメータで変更できるようにしました。指定可能な値は tabs (1個以上のタブ、デフォルト)、singletab (1文字のタブ文字区切り)、spaces (1文字以上のスペースまたはタブ文字の区切り)、 verticalbar ("0個以上の空白 | 0個以上の空白" の区切り) です ([#1420])
* PDFMaker, EPUBMaker, WEBMaker, TEXTMaker, IDGXMLMaker: 全ファイルでなく変換対象ファイルを指定するための `-y`（または`--only`）オプションを追加しました ([#1428], [#1467])
* config.yml のコメント行を含めないようにする `--without-config-comment` オプションを review-init に追加しました ([#1453])
* PDFMaker: `pdfmaker` セクションに `use_original_image_size` パラメータを新設しました。デフォルトでは `//image`, `//indepimage`, `//imgtable` で挿入する画像において、metrics の指定がないときには版面の横幅に合うよう拡縮しますが、`use_original_image_size` パラメータを true に設定すると、拡縮なしで原寸のまま配置します ([#1461])

## 非互換の変更
* PDFMaker: config.yml の `image_scale2width` パラメータを、直下ではなく `pdfmaker` セクションの下に属するように変更しました。互換性のため直下に `image_scale2width` パラメータが存在するときにはそれを尊重しますが、将来的に廃止する可能性があります ([#1462])

## バグ修正
* PDFMaker: Re:VIEW 3 系のプロジェクトとの後方互換処理の誤りを修正しました ([#1414])
* PDFMaker: review-jlreq を LuaLaTeX でコンパイルしたときのエラーを修正しました ([#1416])
* PDFMaker: 索引が目次に含まれない問題を修正しました ([#1418])
* RSTBuilder: メソッドの引数の誤りで変換に失敗する問題を修正しました ([#1426])
* IDGXMLBuilder: 表に関する警告を出すときの誤りを修正しました ([#1427])
* IDGXMLMaker: フィルタプログラムにエラーが発生したときの処理の誤りを修正しました ([#1429])
* PDFMaker: `media=ebook` のときに、見出し等に `@<code>` や `@<tt>` のようなコード書体の命令を使うとビルドに失敗する問題を修正しました ([#1432], [#1465])
* PDFMaker: MeCab がインストールされていないときにエラーになるのを警告に変更しました ([#1445])
* IDGXMLBuilder: `//imgtable` が正しく動作しなかったのを修正しました ([#1448])
* PDFMaker: 索引が1つも登録されていない状態で makeindex を有効にするとエラーになるのを修正しました ([#1467])

## 機能強化
* PDFMaker: 問題報告の解析に役立つよう、提供する cls、sty ファイルについてバージョンを付けるようにしました ([#1163])
* Dockerfile を更新しました ([#1412])
* IDGXMLMaker: フィルタプログラムの標準エラー出力を警告扱いで出力するようにしました ([#1443])
* .gitignore ファイルに 〜-idgxml フォルダ を追加しました ([#1448])
* `//source` 命令は全ビルダでオプションを省略できるようになりました ([#1447])
* Ruby 2.7 をテスト対象に加えました ([#1468])
* `word_files` パラメータは配列で複数の単語 CSV ファイルを受け付けるようになりました ([#1469])

## ドキュメント
* 奥付に関係する `contact` （連絡先）および `colophon_order` （項目の掲載順序）についてのドキュメントを設定ファイルサンプル `config.yml.sample` に追加しました ([#1425])
* quickstart.ja.md, quickstart.md を Re:VIEW 4 の内容に更新しました ([#1442])
* サンプル syntax-book を更新しました ([#1448], [#1449])
* README.md を更新しました ([#1455], [#1458])

## その他
* Rubocop 0.78.0 の指摘に対応しました ([#1424], [#1430])
* LaTeX の実行環境がある場合、PDF のビルドテストをより厳密に実行するようにしました ([#1433])
* ビルドテストを Travis CI から GitHub Actions に切り替えました ([#1431], [#1436], [#1437])
* IDGXMLBuilder のコードリストの処理をリファクタリングしました ([#1438], [#1439])
* サンプル syntax-book に入っていた review-ext.rb はもう不要なので削除しました ([#1446])
* IDGXMLMaker, TextMaker のテストを追加しました ([#1448])
* Index 関連の処理をリファクタリングしました ([#1456], [#1457], [#1459])

## コントリビューターのみなさん
* [@turky](https://github.com/turky)

[#1163]: https://github.com/kmuto/review/issues/1163
[#1412]: https://github.com/kmuto/review/pull/1412
[#1414]: https://github.com/kmuto/review/issues/1414
[#1416]: https://github.com/kmuto/review/issues/1416
[#1418]: https://github.com/kmuto/review/issues/1418
[#1420]: https://github.com/kmuto/review/issues/1420
[#1424]: https://github.com/kmuto/review/pull/1424
[#1425]: https://github.com/kmuto/review/pull/1425
[#1426]: https://github.com/kmuto/review/pull/1426
[#1427]: https://github.com/kmuto/review/pull/1427
[#1428]: https://github.com/kmuto/review/pull/1428
[#1429]: https://github.com/kmuto/review/pull/1429
[#1430]: https://github.com/kmuto/review/pull/1430
[#1431]: https://github.com/kmuto/review/pull/1431
[#1432]: https://github.com/kmuto/review/issues/1432
[#1433]: https://github.com/kmuto/review/pull/1433
[#1436]: https://github.com/kmuto/review/pull/1436
[#1437]: https://github.com/kmuto/review/issues/1437
[#1438]: https://github.com/kmuto/review/pull/1438
[#1439]: https://github.com/kmuto/review/pull/1439
[#1442]: https://github.com/kmuto/review/issues/1442
[#1443]: https://github.com/kmuto/review/pull/1443
[#1445]: https://github.com/kmuto/review/pull/1445
[#1446]: https://github.com/kmuto/review/pull/1446
[#1447]: https://github.com/kmuto/review/issues/1447
[#1448]: https://github.com/kmuto/review/pull/1448
[#1449]: https://github.com/kmuto/review/pull/1449
[#1453]: https://github.com/kmuto/review/pull/1453
[#1455]: https://github.com/kmuto/review/pull/1455
[#1456]: https://github.com/kmuto/review/pull/1456
[#1457]: https://github.com/kmuto/review/pull/1457
[#1458]: https://github.com/kmuto/review/pull/1458
[#1459]: https://github.com/kmuto/review/pull/1459
[#1461]: https://github.com/kmuto/review/issues/1461
[#1462]: https://github.com/kmuto/review/issues/1462
[#1465]: https://github.com/kmuto/review/pull/1465
[#1466]: https://github.com/kmuto/review/pull/1466
[#1467]: https://github.com/kmuto/review/pull/1467
[#1468]: https://github.com/kmuto/review/pull/1468
[#1469]: https://github.com/kmuto/review/issues/1469

# Version 4.0.0
## 新機能
* IDGXML ファイルをまとめて生成する、review-idgxmlmaker を導入しました ([#1337])
* review-textmaker は、imgmath パラメータが有効になっている場合に、数式を画像化するようになりました ([#1338])
* review-init に `-w` オプションを指定することで、Web ブラウザ上で TeX のレイアウトができるウィザードモードを用意しました。なお、この機能は実験的であり、将来別のものに置き換える可能性もあります ([#1403])
* 実験的実装として、複数行から段落を結合する際に、前後の文字の種類に基づいて空白文字の挿入を行う機能を追加しました。この機能を利用するには、unicode-eaw gem をインストールした上で、config.yml に `join_lines_by_lang: true` を追加してください ([#1362])

## 非互換の変更
* 通常の利用では使われることがないので、review-init の実行時に空の layouts フォルダを作成するのをやめました ([#1340])
* PDFMaker: `@<code>`、`@<tt>`、`@<tti>`、`@<ttb>` で空白文字が消えてしまう問題を修正しました。および利便性のために、文字列が版面からあふれるときに途中で改行するようにもしました ([#1348])
* `//texequation`、`//embed`、`//graph` はもともとインライン命令を許容しないので、内容のエスケープもしないようにしました。また、末尾に余計な空行が加わるのも防ぐようにしました ([#1371], [#1374])
* PDFMaker: コラム内での使用を考えて、表の配置のデフォルトを htp (指定位置→ページ上→独立ページの順に試行) から H (絶対に指定位置) にしました (review-style.sty の `\floatplacement{table}` の値) [#1385]
* PDFMaker: コードリスト内では和文欧文間の空きを 1/4 文字ではなく 0 にするようにしました ([#1401])
* config.yml の目次を制御する toc パラメータの値は、これまで null (false、目次は作らない) でしたが、一般的な利用方法を鑑みて、デフォルトを true (目次を作る) に切り替えました ([#1405])

## バグ修正
* review-jlreq がタイプミスのために一部の jlreq.cls バージョンで正しく動作しないのを修正しました ([#1350])
* re ファイルが改行コード CR で記述されたときに不正な結果になるのを修正しました ([#1341])
* PDFMaker: review-jlreq において `//cmd` のブロックがページをまたいだときに文字色が黒になって見えなくなってしまうのを修正しました ([#1363])
* PDFMaker: `@<column>` で「コラム」ラベルが重複して出力されるのを修正しました ([#1367])
* PDFMaker: gentombow.sty と jsbook.cls は review-jsbook の場合のみコピーするようにしました ([#1381])
* PDFMaker: LuaLaTeX で review-jlreq を使ったときに壊れた PDFDocumentInformation ができる問題を修正しました ([#1392])
* PDFMaker: review-jlreq で偶数ページに隠しノンブルが入らなかったのを修正しました ([#1395])

## 機能強化
* IDGXML ビルダで `@<em>` および `@<strong>` をサポートしました ([#1353])
* PDFMaker: コードブロックの各行の処理を `code_line`, `code_line_num` のメソッドに切り出しました ([#1368])
* PDFMaker: デフォルトのコンパイルオプションに `-halt-on-error` を追加しました。TeX のコンパイルエラーが発生したときに即終了することで問題が把握しやすくなります ([#1378])
* PDFMaker: コラム内に脚注 (`@<fn>`) があるときの挙動がコラムの実装手段によって異なり、番号がずれるなどの問題を起こすことがあるため、脚注の文章 (`//footnote`) はコラムの後に置くことを推奨します。コラム内に脚注文章が存在する場合は警告するようにしました ([#1379])
* YAML ファイルのエラーチェックを強化しました ([#1386])
* Logger での表示時に標準の progname を使うようにしました ([#1388])
* PDFMaker: 電子版の作成時に、表紙のページ番号を偶数とし、名前を「cover」にするようにしました ([#1402])
* PDFMaker: `generate_pdf` メソッドのリファクタリングを行いました ([#1404])
* プロジェクトの新規作成時に登録除外ファイル一覧の .gitignore ファイルを置くようにしました ([#1407])

## ドキュメント
* sample-book の README.md を更新しました ([#1354])
* review-jsbook の README.md に jsbook.cls のオプションの説明を追加しました ([#1365])

## その他
* メソッド引数のコーディングルールを統一しました ([#1360])
* `Catalog#{chaps,parts,predef,postdef,appendix}` は String ではなく Array を返すようにしました ([#1372])
* YAML ファイルの読み込みに `safe_load` を使うようにしました ([#1375])
* `table` メソッドをリファクタリングし、ビルダ個々の処理を簡略化しました ([#1356])
* `XXX_header` と `XXX_body` まわりをリファクタリングしました ([#1359])
* `Builder#highlight?` メソッドを HTMLBuilder 以外でも利用できるようにしました ([#1373])
* mkchap* と mkpart* まわりをリファクタリングしました ([#1383])
* Travis CI で rubygems を更新しないようにしました ([#1389])
* Index まわりをリファクタリングしました ([#1390])
* samples フォルダのサンプルドキュメントに review-jlreq のための設定を追加しました ([#1391])
* 用語リストは `:` の前にスペースを入れることを強く推奨するようにしました。スペースがない場合、警告されます ([#1398])

## コントリビューターのみなさん
* [@m-shibata](https://github.com/m-shibata)
* [@masarakki](https://github.com/masarakki)

[#1337]: https://github.com/kmuto/review/issues/1337
[#1338]: https://github.com/kmuto/review/issues/1338
[#1340]: https://github.com/kmuto/review/issues/1340
[#1341]: https://github.com/kmuto/review/issues/1341
[#1348]: https://github.com/kmuto/review/issues/1348
[#1350]: https://github.com/kmuto/review/issues/1350
[#1353]: https://github.com/kmuto/review/pull/1353
[#1354]: https://github.com/kmuto/review/pull/1354
[#1356]: https://github.com/kmuto/review/pull/1356
[#1359]: https://github.com/kmuto/review/pull/1359
[#1360]: https://github.com/kmuto/review/pull/1360
[#1362]: https://github.com/kmuto/review/pull/1362
[#1363]: https://github.com/kmuto/review/issues/1363
[#1365]: https://github.com/kmuto/review/pull/1365
[#1367]: https://github.com/kmuto/review/issues/1367
[#1368]: https://github.com/kmuto/review/issues/1368
[#1371]: https://github.com/kmuto/review/pull/1371
[#1372]: https://github.com/kmuto/review/pull/1372
[#1373]: https://github.com/kmuto/review/pull/1373
[#1374]: https://github.com/kmuto/review/pull/1374
[#1375]: https://github.com/kmuto/review/pull/1375
[#1378]: https://github.com/kmuto/review/pull/1378
[#1379]: https://github.com/kmuto/review/issues/1379
[#1381]: https://github.com/kmuto/review/issues/1381
[#1383]: https://github.com/kmuto/review/issues/1383
[#1385]: https://github.com/kmuto/review/issues/1385
[#1386]: https://github.com/kmuto/review/pull/1386
[#1388]: https://github.com/kmuto/review/pull/1388
[#1389]: https://github.com/kmuto/review/pull/1389
[#1390]: https://github.com/kmuto/review/pull/1390
[#1391]: https://github.com/kmuto/review/pull/1391
[#1392]: https://github.com/kmuto/review/issues/1392
[#1395]: https://github.com/kmuto/review/issues/1395
[#1398]: https://github.com/kmuto/review/issues/1398
[#1401]: https://github.com/kmuto/review/pull/1401
[#1402]: https://github.com/kmuto/review/pull/1402
[#1403]: https://github.com/kmuto/review/pull/1403
[#1404]: https://github.com/kmuto/review/pull/1404
[#1405]: https://github.com/kmuto/review/pull/1405
[#1407]: https://github.com/kmuto/review/pull/1407

# Version 3.2.0

## 非互換の変更
* PDFMaker: `//image` 命令などで画像を配置するときに `\includegraphics` ではなく、それを抽象化した `\reviewincludegraphics` を使うようにしました ([#1318])

## バグ修正
* 別の章の図表やリストを参照する際に章が存在しないとき、内部エラーではなく標準のキーエラーを返すようにしました ([#1284])
* review-compile のエラーメッセージで提示する値の誤りを修正しました ([#1286])
* PDFMaker: review-jsbook において、serial_pagination=true を設定しているとき、PDF のページ番号のメタ情報がおかしくなるのを修正しました ([#1288])
* notoc, nodisp, nonum を含む見出しを `@<hd>` で参照したときに番号が付いてしまうこと、およびその後の見出しの番号がおかしくなることを修正しました ([#1294])
* PDFMaker: jlreq.cls 0401 版利用時に review-jlreq.cls でエラーが出るのを修正しました ([#1298])
* EPUBMaker: EPUB2 の生成に失敗するのを修正しました ([#1301])
* EPUBMaker: Windows で一時フォルダの削除にときどき失敗する現象に対処しました ([#1011])
* PDFMaker: `@<bou>` をサポートしました ([#1220])
* PDFMaker: jlreq.cls の古いバージョンでも動くように対処しました ([#1317])

## 機能強化
* `CHAPS:` が空のときのテストを追加しました ([#1275])
* PDFMaker: 安全のため、reviewtt などのインライン書体命令を RobustCommand マクロで定義するようにしました ([#1280])
* EPUBMaker: デバッグモードで実行する `--debug` オプションを追加しました ([#1281])
* review-epub2html: 脚注をインラインで表現する `--inline-footnote` オプションを追加しました ([#1283])
* EPUBMaker: iBooks 向けに、EPUB3 においても表紙画像のメタデータを入れるようにしました ([#1293])
* PDFMaker: review-jsbook および review-jlreq において、コードリストや数式のキャプションの直後に改ページされる現象を程度抑制するようにしました ([#1299])
* rubocop 0.67.2 に基づいてコードを整形しました ([#1297])
* EPUB 作成のテストを追加しました ([#1300])
* テスト対象の Ruby バージョンを 2.4.6, 2.5.5, 2.6.3 としました ([#1303])
* YAMLLoader のコードを改良しました ([#1304])
* `*` の箇条書きで、`**` から始めたり、`*` のあとに `***` を使ったりといった不正なレベル指定をエラーにしました ([#1313])
* ReVIEW::Location クラスを分離しました ([#1308])
* 箇条書きや文献リストで複数行の英単語が連結されてしまうのを回避しました (ただし PDFMaker のみ) ([#1312])
* 空の表があったときにエラーを出すようにしました ([#1325])
* いくつかのテスト対象を追加しました ([#1327], [#1328])
* MARKDOWNBuilder: ``//listnum``に対応しました ([#1336])

## ドキュメント
* 見出しのレベルの説明の誤りを修正しました ([#1309])

## その他
* もう使われていない ReVIEW::Preprocessor::Strip を削除しました ([#1305])

## コントリビューターのみなさん
* [@uetchy](https://github.com/uetchy)
* [@mitsuo0114](https://github.com/mitsuo0114)

[#1011]: https://github.com/kmuto/review/issues/1011
[#1220]: https://github.com/kmuto/review/issues/1220
[#1275]: https://github.com/kmuto/review/pull/1275
[#1280]: https://github.com/kmuto/review/pull/1280
[#1281]: https://github.com/kmuto/review/issues/1281
[#1283]: https://github.com/kmuto/review/pull/1283
[#1284]: https://github.com/kmuto/review/issues/1284
[#1286]: https://github.com/kmuto/review/pull/1286
[#1288]: https://github.com/kmuto/review/issues/1288
[#1293]: https://github.com/kmuto/review/pull/1293
[#1294]: https://github.com/kmuto/review/issues/1294
[#1297]: https://github.com/kmuto/review/pull/1297
[#1298]: https://github.com/kmuto/review/pull/1298
[#1299]: https://github.com/kmuto/review/pull/1299
[#1300]: https://github.com/kmuto/review/pull/1300
[#1301]: https://github.com/kmuto/review/pull/1301
[#1303]: https://github.com/kmuto/review/pull/1303
[#1304]: https://github.com/kmuto/review/pull/1304
[#1305]: https://github.com/kmuto/review/pull/1305
[#1308]: https://github.com/kmuto/review/pull/1308
[#1309]: https://github.com/kmuto/review/issues/1309
[#1312]: https://github.com/kmuto/review/issues/1312
[#1313]: https://github.com/kmuto/review/issues/1313
[#1317]: https://github.com/kmuto/review/pull/1317
[#1318]: https://github.com/kmuto/review/issues/1318
[#1325]: https://github.com/kmuto/review/issues/1325
[#1327]: https://github.com/kmuto/review/issues/1327
[#1328]: https://github.com/kmuto/review/pull/1328
[#1336]: https://github.com/kmuto/review/pull/1336

# Version 3.1.0

## 非互換の変更
* PDFMaker: 図版のキャプションとして `\reviewimagecaption` マクロを導入しました ([#1254])。Re:VIEW 3 を使っているプロジェクトでは、`review-update` コマンドを実行して review-base.sty ファイルを更新することを推奨します。
* `review-preproc` コマンドから、文書化されておらず正しく動作しない `--strip` オプションを除去しました ([#1257])

## バグ修正
* PDFMaker: 部の中の節番号が前の章の節番号を継続してしまう問題を修正しました ([#1225],[#1226])
* samples 内で gentombow.sty ファイルのコピーが正しくできていないのを修正しました ([#1229])
* PDFMaker: review-jsbook 利用時、numer_of_lines ドキュメントオプションで指定した行数より1行減ってしまうのを修正しました ([#1235])
* PDFMaker: review-jlreq が LuaLaTeX で動作するように修正しました ([#1243])
* EPUBMaker: 部があるときに目次の階層がおかしくなる問題を修正しました ([#1262])
* `//comment` の内容が正しくエスケープされないことがある問題を修正しました ([#1264])
* PDFMaker: 奥付の左列が長いときにあふれるのを修正しました ([#1252])
* CHAPS: が空のときにエラーになるのを修正しました ([#1273])

## 機能強化
* PDFMaker: 数式表現の拡張としてよく使われる amssymb, amsthm, bm パッケージを標準で読み込むようにしました ([#1224])
* HTMLBuilder: emlist, listnum 命令の挙動をほかのコードリスト命令に合わせ、highlight メソッドを必ず経由するようにしました ([#1231])
* EPUBMaker: 脚注から本文に戻るリンクを表現できるようにしました ([#1233])。`epubmaker` パラメータの `back_footnote` サブパラメータを true にすると利用できます。
* PDFMaker: ダミーの行を作成する `\makelines` マクロを追加しました ([#1240])
* `#@warn` 命令を正しく実装しました ([#1258])
* `#@mapfile` 命令に re 拡張子のファイルが指定されたときにはタブなどを整形せずそのまま取り込むようにしました ([#1247])
* Ruby 2.6 をテスト対象にしました ([#1242])
* PDFMaker: review-jlreq で `zw` を使っている箇所を `\zw` に置き換えました。コラム内の段落は字下げするようにしました ([#1250])
* PDFMaker: [#1254] で導入した `\reviewimagecaption` が定義されていないときにはデフォルトのマクロを提供するようにしました ([#1267])

## ドキュメント
* README.md: jsbook.cls のファイル名が誤っていたのを修正しました ([#1239])
* config.yml.sample に back_footnote の説明を追加し、その他いくつかドキュメントに些末な更新を行いました ([#1268])

## コントリビューターのみなさん
* [@doublemarket](https://github.com/doublemarket)
* [@munepi](https://github.com/munepi)

[#1224]: https://github.com/kmuto/review/issues/1224
[#1225]: https://github.com/kmuto/review/pull/1225
[#1226]: https://github.com/kmuto/review/pull/1226
[#1229]: https://github.com/kmuto/review/pull/1229
[#1231]: https://github.com/kmuto/review/issues/1231
[#1233]: https://github.com/kmuto/review/issues/1233
[#1235]: https://github.com/kmuto/review/issues/1235
[#1239]: https://github.com/kmuto/review/pull/1239
[#1240]: https://github.com/kmuto/review/pull/1240
[#1242]: https://github.com/kmuto/review/pull/1242
[#1243]: https://github.com/kmuto/review/issues/1243
[#1247]: https://github.com/kmuto/review/issues/1247
[#1250]: https://github.com/kmuto/review/pull/1250
[#1252]: https://github.com/kmuto/review/issues/1252
[#1254]: https://github.com/kmuto/review/issues/1254
[#1257]: https://github.com/kmuto/review/issues/1257
[#1258]: https://github.com/kmuto/review/issues/1258
[#1262]: https://github.com/kmuto/review/issues/1262
[#1264]: https://github.com/kmuto/review/issues/1264
[#1267]: https://github.com/kmuto/review/issues/1267
[#1268]: https://github.com/kmuto/review/issues/1268
[#1273]: https://github.com/kmuto/review/issues/1273

# Version 3.0.0

## バグ修正
* PDFMaker: review-jsbook の外部ファイル読み込みを調整しました ([#1217])

## コントリビューターのみなさん
* [@munepi](https://github.com/munepi)

[#1217]: https://github.com/kmuto/review/pull/1217

# Version 3.0.0 release candidate
## 非互換の変更
* PDFMaker: review-jsbook の見出しの文字サイズを、オリジナルの jsbook に準拠しました ([#1152])
* PDFMaker: review-jsbook において、3.0.0 preview 4 までの Q,W,L,H で指定する方法をやめ、fontsize などの単位付きパラメータを使うようにしました。3.0.0 preview 3 〜 3.0.0 preview 4 で作成したプロジェクトに対しては、review-update コマンドで新しいパラメータに移行できます ([#1151],[#1201])

## バグ修正
* PDFMaker: review-jsbook クラスファイルで hiddenfolio パラメータと tombopaper パラメータを同時に使用すると hiddenfolio パラメータが無視される問題を修正しました ([#1158])
* PDFMaker: review-jsbook クラスファイルで paperwidth, paperheight パラメータが効かない問題を修正しました ([#1171])
* review-update で sty フォルダの更新が無視されることがあるのを修正しました ([#1183])
* PDFMaker: review-jlreq クラスファイルで serial_pagination および startpage が動作していなかったのを修正しました ([#1204])

## 機能強化
* PDFMaker: review-jsbook において、fontsize パラメータで標準の文字サイズ、baselineskip パラメータで標準の行の高さを pt や Q、mm などの単位付きで指定できるようにしました ([#1151])
* PDFMaker: 何らかの事情でオリジナルの jsbook.cls クラスファイルを使い続けたいユーザー向けに、review-jsbook セットのスタイルファイルを流用可能にしました ([#1177])
* PDFMaker: ユーザーが任意のスタイルや `//embed` 命令で利用できるよう、review-jsbook および review-jlreq に空ページを作成する `\oneblankpage`、必要に応じて改ページすることで次のページが必ず偶数ページになるようにする `\clearoddpage` のマクロを追加しました ([#1175],[#1182])
* PDFMaker: review-jsbook および review-jlreq クラスファイルのドキュメントオプションパラメータに、生成 PDF の種類を指定する `media` を追加しました。3.0.0 preview3 で導入した `cameraready` パラメータと同じ意味です（どちらを使ってもかまいません）([#1181])
* PDFMaker: 部の中で節などの下位見出しを利用できるようになりました ([#1195])
* PDFMaker: 部があるときには `\reviewusepart` というマクロを定義するようにしました ([#1199])
* review-init が生成する config.yml ファイルで、`texdocumentclass` パラメータをコメントアウトされた状態ではなく明示指定するようにしました ([#1202])
* PDFMaker: `//tsize` 命令で幅が明示指定されている場合には、表中の改行（`@<br>`）を `\newline` マクロで表現するようにしました ([#1206])
* PDFMaker: TeX における表の列幅の表現として、`L{幅}`（左寄せ・均等配置なし）, `C{幅}`（中央寄せ）, `R{幅}`（右寄せ） を利用できるようにしました ([#1208])
* PDFMaker: バージョン間の実装差異を避けるため、スナップショットの jsbook.cls (2018/06/23) および gentombow.sty (2018/08/30 v0.9j) を sty フォルダにコピーしてそれを利用するようにしました ([#1210])

## ドキュメント
* IDGXML のドキュメント format_idg.ja.md を更新しました ([#1188])
* クイックスタートガイド quickstart.ja.md に review-update について説明を追加しました ([#1189])
* サンプル設定ファイル config.yml.sample のコメント類を更新しました ([#1190])
* PDFMaker のドキュメント pdfmaker.ja.md を更新しました ([#1191])
* 縦書きについてのドキュメント writing_vertical.ja.md を更新しました ([#1198])
* review-jsbook のドキュメントを更新しました ([#1203])
* review-jlreq のドキュメントを更新しました ([#1204])

## コントリビューターのみなさん
* [@munepi](https://github.com/munepi)

[#1151]: https://github.com/kmuto/review/issues/1151
[#1152]: https://github.com/kmuto/review/issues/1152
[#1158]: https://github.com/kmuto/review/issues/1158
[#1171]: https://github.com/kmuto/review/issues/1171
[#1175]: https://github.com/kmuto/review/pull/1175
[#1177]: https://github.com/kmuto/review/pull/1177
[#1181]: https://github.com/kmuto/review/issues/1181
[#1182]: https://github.com/kmuto/review/pull/1182
[#1183]: https://github.com/kmuto/review/issues/1183
[#1188]: https://github.com/kmuto/review/pull/1188
[#1189]: https://github.com/kmuto/review/pull/1189
[#1190]: https://github.com/kmuto/review/pull/1190
[#1191]: https://github.com/kmuto/review/pull/1191
[#1195]: https://github.com/kmuto/review/issues/1195
[#1198]: https://github.com/kmuto/review/pull/1198
[#1199]: https://github.com/kmuto/review/pull/1199
[#1201]: https://github.com/kmuto/review/pull/1201
[#1202]: https://github.com/kmuto/review/pull/1202
[#1203]: https://github.com/kmuto/review/pull/1203
[#1204]: https://github.com/kmuto/review/pull/1204
[#1206]: https://github.com/kmuto/review/issues/1206
[#1208]: https://github.com/kmuto/review/pull/1208
[#1210]: https://github.com/kmuto/review/issues/1210

# Version 3.0.0 preview 4
## 新機能
* 旧バージョンのプロジェクトを新しいバージョンに合わせたものに更新する `review-update` コマンドを導入しました ([#1144])
* 式を表す `//texequation` に ID の指定による採番およびキャプションを付けられるようにし、`@<eq>` 命令でその参照もできるようにしました ([#1167])

## 非互換の変更
* IDGXMLBuilder、PlaintextBuilder、TextBuilder において `@<chapref>` の展開結果を独自に作成していたのを止め、ほかのビルダと同様に `chapter_quote` のロケール文字列を使うようにしました ([#1160])

## バグ修正
* samples フォルダ内のサンプル集は preview3 でそのままでは PDF を生成できませんでしたが、`rake pdf` だけで動作するように修正しました ([#1156])

## 機能強化
* PDFMaker: review-jlreq.cls クラスファイルでも hiddenfolio パラメータを利用できるようにしました ([#1147])
* EPUBMaker/WEBMaker: imgmath 機能を有効にしたときに、各 `//texequation` に対してフォントサイズを明示して渡すようにしました ([#1146])

[#1144]: https://github.com/kmuto/review/issues/1144
[#1146]: https://github.com/kmuto/review/issues/1146
[#1147]: https://github.com/kmuto/review/issues/1147
[#1156]: https://github.com/kmuto/review/issues/1156
[#1160]: https://github.com/kmuto/review/issues/1160
[#1167]: https://github.com/kmuto/review/issues/1167

# Version 3.0.0 preview 3
## 新機能
* PDFMaker: これまでの jsbook.cls クラスファイルをそのまま使用する方法に代わり、紙・電子双方の書籍制作に適するよう拡張した review-jsbook.cls (jsbook.cls 基盤、デフォルト)、および review-jlreq.cls (jlreq.cls 基盤) を導入しました ([#1032],[#1117])
* EPUBMaker/WEBMaker: `@<m>` や `//texequation` で入れた数式を画像化する imgmath 機能を追加しました ([#868],[#1138])

## 非互換の変更
* PDFMaker: 前付の開始を宣言する LaTeX 命令 `\frontmatter` を、大扉（titlepage）の後ろから大扉の前に移動しました ([#1128])
* PDFMaker: coverimage の表紙の貼り付けは、実寸で中央に配置されるようになりました ([#1064],[#1117])

## バグ修正
* PDFMaker: cover パラメータの扱いの誤りを修正しました ([#1116])
* PDFMaker: 新しいクラスファイルで、preview 2 で発生していた紙面の偏りを修正しました ([#1090],[#1117])

## 機能強化
* PDFMaker: LaTeX に渡す `config.yml` の設定パラメータを増やしました ([#1121])
* PDFMaker: LaTeX 命令 `\begin{document}` の直後に実行されるフックマクロ `\reviewbegindocumenthook`、`\end{document}` の直前に実行されるフックマクロ `\reviewenddocumenthook` を追加しました ([#1111])
* PDFMaker: 新しいクラスファイルでは版面設計をドキュメントオプションで指定するようになったため、geometry.sty は不要になりました ([#912])
* PDFMaker: 新しいクラスファイルで、大扉からの通しノンブルをサポートしました ([#1129])
* `review-init` コマンドにネットワークダウンロードの機能を追加しました。`-p` オプションで zip ファイルの URL を指定すると、生成したプロジェクトフォルダに zip ファイルを展開して上書きします ([#812])
* PDFMaker: デジタルトンボや隠しノンブルを表現するために外部 TeX パッケージの gentombow パッケージを取り込み、プロジェクトフォルダの sty フォルダにコピーするようにしました ([#1136])

## ドキュメント
* Kindle 用の電子書籍ファイルを作る方法を doc/customize_epub.ja.md に追記しました ([#1114])
* サンプルファイルなどにある PDFMaker のデフォルトのドキュメントオプションの例示を新しいクラスファイルに合わせました ([#1115])
* `review-init` コマンドで展開されるファイルなど、扱いが明示されていなかったファイルについてライセンスを明記しました ([#1093],[#1112])
* 数式を画像化する `imgmath` について、doc/format.ja.md に追記しました ([#868])

## コントリビューターのみなさん
* [@munepi](https://github.com/munepi)

[#812]: https://github.com/kmuto/review/issues/812
[#868]: https://github.com/kmuto/review/issues/868
[#912]: https://github.com/kmuto/review/issues/912
[#1032]: https://github.com/kmuto/review/issues/1032
[#1064]: https://github.com/kmuto/review/issues/1064
[#1090]: https://github.com/kmuto/review/issues/1090
[#1093]: https://github.com/kmuto/review/issues/1093
[#1111]: https://github.com/kmuto/review/pull/1111
[#1112]: https://github.com/kmuto/review/pull/1112
[#1114]: https://github.com/kmuto/review/pull/1114
[#1115]: https://github.com/kmuto/review/issues/1115
[#1116]: https://github.com/kmuto/review/pull/1116
[#1117]: https://github.com/kmuto/review/pull/1117
[#1121]: https://github.com/kmuto/review/pull/1121
[#1128]: https://github.com/kmuto/review/issues/1128
[#1129]: https://github.com/kmuto/review/pull/1129
[#1136]: https://github.com/kmuto/review/issues/1136
[#1138]: https://github.com/kmuto/review/issues/1138

# Version 3.0.0 preview 2

## 新機能
* CSS 組版向けに EPUB ファイルを単一 HTML ファイルに変換する `review-epub2html` コマンドを追加しました ([#1098])

## 非互換の変更
* PDFMaker: `texcommand`、`dvicommmand`、`makeindex_command` に空白文字入りのパスを指定できるようにしました。これに伴い、これらのパラメータはコマンドオプションを取ることはできなくなりました。コマンドオプションは本来の `texoptions`、`dvioptions`、`makeindex_options` のパラメータに指定してください ([#1091])
* PDFMaker: book.re というファイルで生じるビルドの失敗を修正しました。これまではベースファイルとして `book.tex` という名前のファイルを内部で作成していましたが、`__REVIEW_BOOK__.tex` という名前に変更しました ([#1081])
* PDFMaker: jsbook ベーススタイルにおいて、geometry を読み込まないようにしました ([#912])
* PDFMaker: jsbook ベーススタイルにおいて、ページ番号を見開きの左右に振るようにしました ([#1032])
* `@<chapref>`、`@<hd>`、`@<column>` 命令の展開文字列をビルダ間で統一するとともに、`locale.yml` ファイルで変更できるようにしました。`@<chapref>` はデフォルトでは `第1章「FOO」` のようになります（`chapter_quote`、`chapter_quote_without_number` で変更可）。`chapter_quote` メッセージは2つの `%s` を取るようになりました。`@<hd>` は `「2.1 BAR」` のようになります（`hd_quote`、`hd_quote_without_number` で変更可）。`@<column>` は `コラム「BAZ」` のようになります（`column` で変更可） ([#886])

## バグ修正
* EPUBMaker: OPF ファイルの modified の時刻の表記を正しい UTC 値にしました ([#1094])
* `contentdir` パラメータでサブフォルダを使用しているときに、参考文献ファイルがそのフォルダから読まれない問題を修正しました ([#1103])
* PDFMaker: 索引辞書の読み込みなど、パラメータで指定したファイルのパスが解決されない問題を修正しました ([#1086])
* preview 1 でのフェンス記法内のエスケープの不具合を修正しました ([#1083])
* サンプル CSS 内の不要なタブ文字を除去しました ([#1084])

## 機能強化
* PDFMaker: tableとfigureでのフロート設定をマクロ `\floatplacement` で定義できるようにしました ([#1095])
* EPUBMaker: エラーと警告の出力に logger 機能を利用するようにしました ([#1077])
* PDFMaker: `dvicommand` パラメータが null の場合は、dvipdfmx などの変換コマンドを呼び出さないようにしました ([#1065])

## ドキュメント
* サンプルドキュメントを samples フォルダに移動しました ([#1073])
* `config.yml.sample` に索引関連のフックおよびパラメータのコメントを追加しました ([#1097])
* quickstart.md のタイプミスを修正しました ([#1079])

## コントリビューターのみなさん
* [@aiya000](https://github.com/aiya000)
* [@sho-h](https://github.com/sho-h)
* [@kateinoigakukun](https://github.com/kateinoigakukun)

[#886]: https://github.com/kmuto/review/issues/886
[#912]: https://github.com/kmuto/review/issues/912
[#1032]: https://github.com/kmuto/review/issues/1032
[#1065]: https://github.com/kmuto/review/pull/1065
[#1073]: https://github.com/kmuto/review/issues/1073
[#1077]: https://github.com/kmuto/review/pull/1077
[#1079]: https://github.com/kmuto/review/pull/1079
[#1080]: https://github.com/kmuto/review/issues/1080
[#1081]: https://github.com/kmuto/review/pull/1081
[#1083]: https://github.com/kmuto/review/issues/1083
[#1084]: https://github.com/kmuto/review/pull/1084
[#1086]: https://github.com/kmuto/review/issues/1086
[#1091]: https://github.com/kmuto/review/pull/1091
[#1094]: https://github.com/kmuto/review/pull/1094
[#1095]: https://github.com/kmuto/review/pull/1095
[#1097]: https://github.com/kmuto/review/pull/1097
[#1098]: https://github.com/kmuto/review/pull/1098
[#1103]: https://github.com/kmuto/review/pull/1103

# Version 3.0.0 preview 1

## 新機能
* `contentdir` パラメータで、re ファイルをサブフォルダに配置してそのフォルダを指定できるようにしました ([#920], [#938])
* `//graph` 命令 で PlantUML をサポートしました ([#1006],[#1008])
* CSV 形式の単語ファイルから指定キーに対応する値を展開する、`@<w>` および `@<wb>` 命令を追加しました ([#1007], [#1010])
* catalog.ymlにある`*.re`ファイルが存在しない場合エラーになるようにしました ([#957])
* LATEXBuilder: LaTeX でルビを表現できるよう pxrubrica パッケージを読み込むようにしました ([#655])
* LATEXBuilder: 複数の LaTeX レイアウトファイルから選択できるようにしました ([#812])
* `@<balloon>`を標準サポートタグとしました ([#829])
* LATEXBuilder: `@<uchar>`でUnicode文字を直接出力できるようにしました ([#1045])
* RakefileのオプションでCONFIG_FILEを上書きできるようにしました ([#1059])

## 非互換の変更
* review_version の値が 3 以上のときには、LaTeX の `@<m>` によるインラインの数式の前後にスペース文字を入れないようにしました ([#943])
* HTML ビルダにおいて、`//list`, `//listnum` で識別子に基づくハイライト言語の自動検出をやめました (ハイライト言語は命令の 3 つめのオプションで指定してください) ([#1016])
* LATEXBuilder: layout.tex.erbを整理・再構成しました ([#950])
* LATEXBuilder: LaTeX のコードリストを reviewlistblock 環境で囲むようにしました ([#916])
* LATEXBuilder: LaTeX のコードリスト環境を jlisting から plistings パッケージに変更しました ([#635])
* LATEXBuilder: PDF生成時にリンクの枠線について、標準では消すようにしました ([#808])
* LATEXBuilder: インライン文字装飾の LaTeX への変換結果を`\textbf`ではなく`\reviewbold`のように抽象化した名前にしました ([#792])
* LATEXBuilder: LaTeX の表紙 (coverパラメータ) と大扉 (titlepageパラメータ) は独立した設定となりました ([#848])
* review-preproc: --final オプションを削除しました ([#993])
* LATEXBuilder: キャプションブロックの出力について`reviewminicolumn`を使わず`reviewnote`等を使うようにしました ([#1046])

## バグ修正
* Ruby 2.3 以下で実行時のログ表示が冗長になるのを修正しました ([#975])
* Version 2.5.0 で削除した `usepackage` パラメータを、互換性のために戻しました ([#1001])
* HTMLBuilder: `@<m>`や`//texequation{...//}`でのログ出力を抑制するようにしました ([#1027])
* LATEXBuilder: リストのキャプションが空の場合の出力を修正しました ([#1040])
* MeCabのロードパスを修正しました ([#1063])

## 機能強化
* Windows でも `//graph` 命令が動作するようにしました ([#1008])
* 画像ファイルやフォントファイルの拡張子が大文字・小文字どちらでも利用できるようにしました ([#1002])
* review-pdfmaker: pdfmakerで実行したコマンド情報を出力するようにしました ([#962],[#968])
* IDGXMLBuilder: `=[notoc]`および`=[nodisp]`をサポートしました ([#1022])
* PDFMaker: psdファイルもコピーするようにしました ([#879])
* PDFMaker: config.ymlの `texoptions`のデフォルト値を変更してLaTeX実行中に入力待ちにしないようにしました ([#1029])
* LATEXBuilder: LaTeXなどのログメッセージを正常時には出力しないようにしました ([#1036])
* MARKDOWNBuilder: サポートするコマンドを追加しました ([#881])
* image_finder.rb: シンボリックリンクされたディレクトリをサポートしました ([#743])
* Rakefileの依存関係にcatalog.ymlなどのファイルを追加しました ([#1060])

## ドキュメント
* `//graph` 命令の各外部ツールについての説明を追加しました ([#1008])
* `@<w>`, `@<wb>` 命令の説明を追加しました ([#1007])
* LaTeX から生成する PDF の圧縮レベルオプション指定 (-z 9、最大圧縮) を config.yml のサンプルに記載しました ([#935])

## コントリビューターのみなさん
* [@TeTiRoss](https://github.com/TeTiRoss)
* [@kauplan](https://github.com/kauplan)
* [@munepi](https://github.com/munepi)
* [@m-shibata](https://github.com/m-shibata)

[#635]: https://github.com/kmuto/review/issues/635
[#655]: https://github.com/kmuto/review/issues/655
[#743]: https://github.com/kmuto/review/issues/743
[#792]: https://github.com/kmuto/review/issues/792
[#808]: https://github.com/kmuto/review/issues/808
[#812]: https://github.com/kmuto/review/issues/812
[#829]: https://github.com/kmuto/review/issues/829
[#848]: https://github.com/kmuto/review/issues/848
[#879]: https://github.com/kmuto/review/issues/879
[#881]: https://github.com/kmuto/review/issues/881
[#916]: https://github.com/kmuto/review/issues/916
[#920]: https://github.com/kmuto/review/issues/920
[#938]: https://github.com/kmuto/review/issues/938
[#935]: https://github.com/kmuto/review/issues/935
[#943]: https://github.com/kmuto/review/issues/943
[#950]: https://github.com/kmuto/review/issues/950
[#957]: https://github.com/kmuto/review/issues/957
[#962]: https://github.com/kmuto/review/issues/962
[#968]: https://github.com/kmuto/review/issues/968
[#975]: https://github.com/kmuto/review/issues/975
[#993]: https://github.com/kmuto/review/issues/993
[#1001]: https://github.com/kmuto/review/pull/1001
[#1002]: https://github.com/kmuto/review/issues/1002
[#1006]: https://github.com/kmuto/review/issues/1006
[#1007]: https://github.com/kmuto/review/issues/1007
[#1008]: https://github.com/kmuto/review/pull/1008
[#1010]: https://github.com/kmuto/review/pull/1010
[#1016]: https://github.com/kmuto/review/issues/1016
[#1022]: https://github.com/kmuto/review/issues/1022
[#1027]: https://github.com/kmuto/review/issues/1027
[#1029]: https://github.com/kmuto/review/issues/1029
[#1036]: https://github.com/kmuto/review/issues/1036
[#1040]: https://github.com/kmuto/review/issues/1040
[#1045]: https://github.com/kmuto/review/issues/1045
[#1046]: https://github.com/kmuto/review/issues/1046
[#1059]: https://github.com/kmuto/review/issues/1059
[#1060]: https://github.com/kmuto/review/issues/1060
[#1063]: https://github.com/kmuto/review/issues/1063

# Version 2.5.0

## 新機能
* プレインテキストを出力する review-textmaker コマンドを用意しました ([#926])
* LaTeX 向けに、図版の BoudingBox の採取手段を変更する `pdfmaker/bbox` パラメータを追加しました ([#947])
* 新機能：空行を入れる命令 `//blankline` を追加しました ([#942])

## 非互換の変更
* `//include` 命令は不完全でユーザーの混乱を招くため、削除しました ([#887])
* LaTeX において、見出しや図表キャプション内にある脚注は `\footnotemark` を暗黙に使うようにしました ([#841])
* EPUB および WebMaker の大扉では、印刷所 (prt) の代わりに出版社 (pbl) を記載するようにしました ([#927])
* PDFMaker における layout.tex.erb の `usepackage` パラメータは、`texstyle` パラメータに置き換えられました。書式も変更されているので、独自の layoute.tex.erb を使っている場合は書き換えが必要です ([#908])

## バグ修正
* column の終了が正しく動作しないのを修正しました ([#894])
* `@<hd>` 命令の使用時に内部エラーが出ることがあるのを修正しました ([#896])
* LaTeX において、キャプションが空のときに空行が入ってしまうのを修正しました ([#922])
* `//graph` 命令内で gnuplot を使用したときにエラーが発生するのを修正しました ([#931])
* Windows で review コマンドがエラーになるのを修正しました ([#940])
* Windows で EPUB 生成時に一時作業ファイルの削除エラーが発生するのを修正しました ([#946])

## 機能強化
* `//note` などの囲み要素内で末尾に空行があるときに不要な空の段落が作成されるのを修正しました ([#882])
* `@<chap>` などで catalog.yml に存在しない ID を指定したときのエラーメッセージをわかりやすいものにしました ([#891])
* catalog.yml に UTF-8 BOM ヘッダがあっても正常に動作するようにしました ([#899])
* LaTeX の奥付の罫線の長さを固定幅ではなく紙面幅にしました ([#907])
* texstyle パラメータで配列による複数の TeX スタイルファイルの読み込みを許可するようにしました ([#908])
* 独自の Rakefile を利用するための `lib/tasks` フォルダを `review-init` コマンドで作成するようにしました ([#921])
* `review-init` コマンド実行時に、`doc` フォルダにドキュメントをコピーするようにしました ([#918])
* `review` コマンドのヘルプメッセージを追加しました ([#933])
* 存在しないあるいは壊れている YAML ファイルを読み込もうとしたときに妥当なエラーメッセージを出すようにしました ([#958])
* `@<img>` や `@<table>` などのインライン命令で存在しない ID を指定したときのエラーメッセージをわかりやすいものに統一しました ([#954])
* catalog.yml に存在しないファイルをコンパイルしようとしたときのエラーメッセージをわかりやすいものにしました ([#953])
* LaTeX において、table, imgtable, image, indepimage から変換した TeX ソースコードにコメントで ID を記述するようにしました（`\begin{reviewimage}%%sampleimg` など）。フック処理での書き換えを簡易化するための修正であり、通常のLaTeX(PDF)の出力には影響ありませんが、独自のフック処理を使用していたプロジェクトでは修正が必要になるかもしれません ([#937])

## ドキュメント
* 画像ファイルの拡張子の探索順序を文書化しました ([#939])
* review-textmaker の説明を追加しました ([#944])

## コントリビューターのみなさん
* [@kauplan](https://github.com/kauplan)
* [@krororo](https://github.com/krororo)
* [@mhidaka](https://github.com/mhidaka)
* [@Pegasus204](https://github.com/Pegasus204)

[#841]: https://github.com/kmuto/review/issues/841
[#882]: https://github.com/kmuto/review/issues/882
[#887]: https://github.com/kmuto/review/issues/887
[#891]: https://github.com/kmuto/review/issues/891
[#894]: https://github.com/kmuto/review/pull/894
[#896]: https://github.com/kmuto/review/issues/896
[#899]: https://github.com/kmuto/review/issues/899
[#907]: https://github.com/kmuto/review/pull/907
[#908]: https://github.com/kmuto/review/pull/908
[#918]: https://github.com/kmuto/review/issues/918
[#921]: https://github.com/kmuto/review/issues/921
[#922]: https://github.com/kmuto/review/pull/922
[#926]: https://github.com/kmuto/review/issues/926
[#927]: https://github.com/kmuto/review/pull/927
[#931]: https://github.com/kmuto/review/pull/931
[#933]: https://github.com/kmuto/review/issues/933
[#937]: https://github.com/kmuto/review/pull/937
[#939]: https://github.com/kmuto/review/pull/939
[#940]: https://github.com/kmuto/review/issues/940
[#942]: https://github.com/kmuto/review/issues/942
[#944]: https://github.com/kmuto/review/pull/944
[#946]: https://github.com/kmuto/review/issues/946
[#947]: https://github.com/kmuto/review/pull/947
[#953]: https://github.com/kmuto/review/issues/953
[#954]: https://github.com/kmuto/review/issues/954
[#958]: https://github.com/kmuto/review/issues/958

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
[#794]: https://github.com/kmuto/review/issues/794
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
    * `prt` は `発行所` ではなく `印刷所` になります. `発行所` は `pbl` です.([#562], [#593])
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

[#465]: https://github.com/kmuto/review/issues/465
[#473]: https://github.com/kmuto/review/issues/473

# Version 1.7.1の主な変更点

## バグ修正
* latexbuilderで`//listnum`のキャプションが2重に出力されるバグを修正しました ([#465])
* review-initで生成される雛形を元にEPUB3のファイルを作成するとepubcheck 4.0.1でエラーになるバグを修正しました ([#456])

[#456]: https://github.com/kmuto/review/issues/473

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
