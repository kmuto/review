# Re:VIEW フォーマット InDesign XML 形式拡張

Re:VIEW フォーマットから、Adobe 社の DTP ソフトウェア「InDesign」
で読み込んで利用しやすい XML 形式に変換できます (通常の XML とほぼ同じ
ですが、文書構造ではなく見た目を指向した形態になっています)。
現時点では idgxmlbuilder.rb と topbuilder.rb のみが拡張に対応しています。
実際には出力された XML を InDesign のスタイルに割り当てるフィルタをさらに
作成・適用する必要があります。

## 章・節・項・段

従来の`[column]`のほかに、オプションを追加しています。

* `[nonum]` : これを指定している章・節・項・段には連番を振りません。
* `[circle]`: 「・」を先頭に付けた小さな見出し(連番なし)を作成します。
* `[world]`: Real Worldコラム。
* `[hood]`: Under the Hoodコラム。
* `[edition]`: Editionコラム。
* `[insideout]`: インサイドアウトコラム。

## 書式ブロック

`//insn[タイトル]{ 〜 //}` または `//box[タイトル]{ 〜 //}` で書式を指定します。

## ノート

`//note{ 〜 //}` または `//note[タイトル]{ 〜 //}` で注意文章を指定します。

## メモ

`//memo{ 〜 //}` または `//memo[タイトル]{ 〜 //}` でメモ文章を指定します。

## ヒント

`//tip{ 〜 //}` または `//tip[タイトル]{ 〜 //}` でヒント(Tip)文章を指定します。

## 参照ブロック

`//info{ 〜 //}` または `//info[タイトル]{ 〜 //}` で参照文章を指定します。

## プランニング

`//planning{ 〜 //}` または `//planning[タイトル]{ 〜 //}` でプランニング文章を指定します。

## ベストプラクティス

`//best{ 〜 //}` または `//best[タイトル]{ 〜 //}` でベストプラクティス文章を
指定します。

## ここが重要 (キーワード)

`//important[タイトル]{ 〜 //}` で重要項目を指定します。

## セキュリティ

`//security{ 〜 //}` または `//security[タイトル]{ 〜 //}` でセキュリティ文章を
指定します。

## 警告

`//caution{ 〜 //}` または `//caution[タイトル]{ 〜 //}` で警告文章を指定します。

## エキスパートに訊く

`//expert{ 〜 //}` で「エキスパートに訊く」を指定します (rawで`<expert>〜</expert>`
を使うほうがよいかもしれません)。
QとAは`@<b>{Q}：〜` と `@<b>{A}：〜` で示します。

## 注意

`//notice{ 〜 //}` または `//notice[タイトル]{ 〜 //}` で注意を指定します。

## ワンポイント

`//point{ 〜 //}` または `//point[タイトル]{ 〜 //}` でワンポイントを指定します。

## トラブルシューティング

`//shoot{ 〜 //}` または `//shoot[タイトル]{ 〜 //}` でトラブルシューティングを
指定します。

## 用語解説

`//term{ 〜 //}` で用語解説を指定します(ただし、ブロック指定ができないので
実質的にはrawで`<term>〜</term>`を通常使うことになるでしょう)。

## リンク

`//link{ 〜 //}` または `//link[タイトル]{ 〜 //}` で他の章やファイルなどへの
参照内容を指定します。

## 練習問題

`//practice{ 〜 //}` で練習問題を指定します。

## 参考

`//reference{ 〜 //}` で参考情報を指定します。

## 相互参照

`//label[〜]`でラベルを定義し、`@<labelref>{〜}`で参照します。
XMLとしては`<label id='〜' />`と`<labelref idref='〜' />`というタグに
置き換えられます。
実際にどのような相互参照関係にするかは、処理系に依存します。
想定の用途では、章や節の番号およびタイトルを記憶し、labelrefの出現箇所
に"「節(あるいは章)番号　タイトル」"という文字列を配置します。

`@<chapref>`の展開形式を、`--chapref="前装飾文字列,中間装飾文字列,後装飾文字列"`
でコンパイル実行時に指定できます。デフォルトは`",「,」"`です。たとえば
"`第2章「コンパイラ」`" のように普通は展開されます。
`"「,　,」"`と指定すると、"`「第2章　コンパイラ」`" に展開されます。

## 丸数字

`@<maru>{数値}` で丸数字を出力します。

## キートップ

`@<keytop>{キー文字}` でキーボードマークを出力します。

## 吹き出し

`@<balloon>{〜}` でコード内などでの吹き出しを作成します。吹き出しは右に寄せ
られ、記入した箇所から吹き出しまで線が引かれます。
`@<>`オペレータは入れ子ができないため、丸数字を使いたいときには`@maru[数値]`
という特別な書式を代わりに使います。

## ロー指定

現時点で Re:VIEW はブロックの入れ子処理ができないため、ロー指定で XML
エレメントを指定しなければならないこともあります。

インラインの`@<raw>{ 〜 }`の他に、単一行の`//raw[〜]`、ブロック版の `//rawblock{ 〜 //}` でも、フォーマット処理をせずにそのままの文字列が出力できます。

## キャプションなし表

`//table{ 〜 //}` のように id もキャプションも付けないブロックを利用できます。
この場合、その表の連番付けを飛ばします。

## 表セル幅の指定

`//tsize[1列目の幅,2列目の幅,...]` で、続く `//table` の表の列幅を指定します
(単位mm)。これを利用するときには、review2idgxml を実行する際、オプション
`--table=表幅` を付ける必要があります (表幅の単位は mm)。列幅指定の個数が
実際の列数に満たない場合、残りの列は均等分割したものとなります。列幅の
合計が表幅を超えるとエラーになります。

## DTP 命令指定

`@<dtp>{ 〜 }` で InDesign 向けに「`<? dtp 〜 ?>`」型の XML インストラクション
を埋め込みます。処理系に渡す任意の文字列を指定できますが、次のような文字列
を特殊文字指定できます。

* maru	番号リストの各段落先頭で使い、このリスト段落の番号は丸数字であることを示す
* return  改行記号文字
* autopagenumber	現ページ番号
* nextpageunmber	次ページ番号
* previouspagenumber	前ページ番号
* sectionmarker	セクションマーカー
* bulletcharacter	ビュレット (ナカグロ)
* copyrightsymbol	著作権記号
* degreesymbol	度記号
* ellipsischaracter	省略記号
* forcedlinebreak	強制改行
* discretionarylinebreak	任意の改行
* paragraphsymbol	段落記号
* registeredtrademark	登録商標記号
* sectionsymbol	セクション記号
* trademarksymbol	商標記号
* rightindenttab	右インデントタブ
* indentheretab	「ここまでインデント」タブ
* zerowidthnonjoiner	結合なし
* emdash	EMダッシュ
* endash	ENダッシュ
* discretionaryhyphen	任意ハイフン
* nonbreakinghyphen	分散禁止ハイフン
* endnestedstyle	先頭文字スタイルの終了文字
* doubleleftquote	左二重引用符
* doublerightquote	右二重引用符
* singleleftquote	左用符
* singlerightquote	右引用符
* singlestraightquote	半角一重左用符
* doublestraightquote	半角二重引用符
* emspace	EMスペース
* enspace	ENスペース
* flushspace	フラッシュスペース
* hairspace	極細スペース
* nonbreakingspace	分散禁止スペース
* fixedwidthnonbreakingspace	分散禁止スペース（固定幅）
* textvariable	全角スペース
* thinspace	細いスペース
* figurespace	数字の間隔
* punctuationspace	句読点等の間隔
* sixthspace	1/6スペース
* quarterspace	1/4スペース
* thirdspace	1/3スペース
* columnbreak	改段
* framebreak	改フレーム
* pagebreak	改ページ
* oddpagebreak	奇数改ページ
* evenpagebreak	偶数改ページ
* footnotesymbol	脚注記号
