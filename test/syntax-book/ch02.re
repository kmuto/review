= 長い章見出し■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□

== ブロック命令
=== ソースコード
採番付きリストの場合はlistです（@<list>{list2-1}）。

//list[list2-1][@<b>{Ruby}の@<tt>{hello}コード@<fn>{f2-1}][ruby]{
puts 'Hello, World!'
//}

//footnote[f2-1][コードハイライトは外部パッケージに委任しています。TeXではjlisting、HTMLではRouge？]

行番号と採番付きのリストはlistnumです。

//listnum[list2-2][行番号はリテラルな文字で特に加工はしていない][ruby]{
class Hello
  def initialize
    @msg = 'Hello, World!'
  end
end
//}

採番なしはemlistを使います。キャプションはあったりなかったりします。

//emlist[][c]{
printf("hello");
//}

//emlist[Python記法][python]{
print('hello');
//}

行番号付きのパターンとしてemlistnumがあります。

//emlistnum[][c]{
printf("hello");
//}

//firstlinenum[101]
//emlistnum[Python記法][python]{
print('hello');
//}

ソースコード引用を主ターゲットにするのには一応sourceというのを用意しています@<fn>{type}。

//footnote[type][書籍だと、いろいろ使い分けが必要なんですよ……（4、5パターンくらい使うことも）。普通の用途ではlistとemlistで十分だと思いますし、見た目も同じでよいのではないかと。TeXの抽象タグ名は変えてはいます。]

//source[hello.rb][ruby]{
puts 'Hello'
//}

#@# //source{
#@# //}
#@# FIXME:キャプションなしはLaTeXだとエラーになることがわかった。Re:VIEW側修正予定

実行例を示すとき用にはcmdを用意しています。いずれにせよ、商業書籍レベルでは必要なので用意しているものの、原稿レベルで書き手が使うコードブロックはほどほどの数に留めておいたほうがいいのではないかと思います。TeX版の紙面ではデフォルトは黒アミ。印刷によってはベタ黒塗りはちょっと怖いかもなので、あまり長々したものには使わないほうがいいですね。

//cmd{
$ @<b>{ls /}
//}

=== 図
採番・キャプション付きの図の貼り付けはimageを使用します（@<img>{ball}）。図版ファイルは識別子とビルダが対応しているフォーマットから先着順に探索されます。詳細については@<href>{https://github.com/kmuto/review/wiki/ImagePath, ImagePath}のドキュメントを参照してください。

@<fn>{madebygimp}
本当はimageのキャプションにfootnoteを付けたいのですが、TeXではエラーになりますね。厳しい……。
#@# FIXME:TeXのキャプションfootnote問題

#@# //image[ball][ボール@<fn>{madebygimp}]{
//image[ball][ボール]{
//}

//footnote[madebygimp][GIMPのフィルタで作成。@<br>{}footnote内改行]

//noindent
（いちおう、@<tt>{config.yml}ファイルに@<tt>{footnotetext: true}を追加すれば、footnotemark/footnotetextを使うモードになりますが）

採番なし、あるいはキャプションもなしのものはindepimageを使います。

//indepimage[logic]{
//}

//indepimage[logic2][採番なしキャプション]{
//}

=== 表
表はtableを使います。@<table>{tab2-1}

tableもキャプション・セル内含めてTeXでは脚注できないですね…
本当は→@<fn>{tabalign}はキャプション内。TeXだとセル内の脚注は脚注文書が消えています。

#@# //table[tab2-1][表の@<b>{例}@<fn>{tabalign}]{
//table[tab2-1][表の@<b>{例}]{
A	B	C
----------------------------------
D	E@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}	F@<br>{}G
H	I@<fn>{footi}	長いセルの折り返し■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□
//}
#@# FIXME:ヘッダセルにはreviewthを付けているけれども、TeXスタイルで何も使っていないのはもったいないかも。アミかけるかベタ塗りにして白抜きにする？

//footnote[tabalign][現状、表のalignmentとかjoinとかはRe:VIEW記法では対応していません。筆者自身の制作では@<href>{https://kmuto.jp/d/?date=20120208#p01}みたいな手法を使っています。]
//footnote[footi][表内の脚注っていろいろ難しいです。]

TeX向けにはtsizeでTeX形式の列指定自体は可能です。以下は@<code>{//tsize[|latex|p{10mm\}p{18mm\}|p{50mm\}]}としています。

//tsize[|latex|p{10mm}p{18mm}|p{50mm}]
//table{
A	B	C
----------------------------------
D	E@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}	F@<br>{}G
H	I	長いセルの折り返し■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□■□
//}

TeXの普通のクラスファイルだと、列指定はl,c,r,p（幅指定+左均等）しかないので、幅指定+左寄せ（均等なし）、幅指定+中寄せ、幅指定+右寄せの指定ができると嬉しそうです。

あとは縦に長い表がTeXだとそのままはみ出してしまうのでlongtableがあるけれどもそれはまた問題がいろいろあり……。

採番はしたくないけれどもキャプションは指定したいという場合はemtableがあります。

//emtable[キャプションを指定したいが採番はしたくない表]{
A	B
C	D
//}

画像にしておいて貼り付けたほうがよさそうな場合はimgtableを使います（@<table>{table}）。

//imgtable[table][ポンチ表]{
//}

=== 囲み記事
@<embed>{/}/{〜//}の囲み記事の中には段落のみしか入らないものと想定します（箇条書きなどを入れたい場合はユーザーの責任で適宜、変換後ソースを加工してもらうことを前提とします）。

引用はquoteで表現します。上下アキ、左インデント（2文字くらい？）が入るのが一般的でしょうか。

//quote{
ここに引用文。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

2行目の引用文。
//}

中寄せはcenteringです。

//flushright{
中寄せ本文。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

2行目の中寄せ本文。
//}

右寄せはflushrightです。

//flushright{
右寄せ本文。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

2行目の右寄せ本文。
//}

ノートnote。以降、キャプションあり/なしのパターンがあります。表現については結局紙面デザインに応じて千差万別になるものだと思いますので、基本デザインとしては何か囲み要素だとわかって、カスタマイズしやすければよい、という程度です。

//note[ノートの例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
ノート1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

ノート2。
//}

//note{
ノート。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

メモmemo。

//memo[メモの例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
メモ1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

メモ2。
//}

//memo{
メモ。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

Tips tip。

//tip[Tipsの例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
Tips1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

Tips2。
//}

//tip{
Tips。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

情報 info。

//info[情報の例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
情報1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

情報2。
//}

//info{
情報。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

注意 warning。

//warning[注意の例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
注意1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

注意2。
//}

//warning{
注意。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

重要 important。

//important[重要の例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
重要1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

重要2。
//}

//important{
重要。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

警告 caution。

//caution[警告の例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
警告1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

警告2。
//}

//caution{
警告。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

注意 notice。

//notice[注意の例@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}]{
注意1。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}

注意2。
//}

//notice{
注意。@<b>{太字bold}@<i>{italicイタ}@<tt>{等幅code}
//}

脚注が入ることもあり得ます。

//notice[脚注がある注意@<fn>{notice1}]{
こちらにも脚注@<fn>{notice2}
//}

//footnote[notice1][noticeの見出し側脚注です。]
//footnote[notice2][noticeの文章側脚注です。]
#@# FIXME:囲み内でも本当はなるべく脚注は版面下のほうに置きたい

#@# doorquote、bpo、talk、graph、address、box、linebreak、pagebreak、hr、comment、abbr、acronym、dfn、kbd、q、samp、var、big、small、del、ins、recipe、dtp、raw、embed、include

== LaTeX式
LaTeX式はTeX紙面以外は保証されません。EPUBではMathML（@<tt>{mathml: true}）を使えますが、表現や互換性が不足しており、LaTeXをバックエンドとして画像化する@<tt>{imgmath: true}のほうがよさそうです。

//texequation{
\sum_{i=1}^nf_n(x)
//}

//texequation{
A = \left(
\begin{array}{ccc}
a_{11} & \cdots & a_{1n} \\
\vdots & \ddots & \vdots \\
a_{m1} & \cdots & a_{mn}
\end{array}
\right)
//}

式採番がほしいケースは多々発生しているので、標準の文法を拡張する必要があるように思っています（現状、@<tt>{review-ext.rb}でなんとかしていることが多いです）。

段落中の式は@<m>{E=mc^2}というシンプルなものならまだよいのですが、@<m>{\sinh^{-1\} x = \log(x + \sqrt{x^2 + 1\}}のような形だと}のエスケープで読みにくめです。今のところRubyにあるようなフェンス文法を実装するのも難しいですね。@<m>{\sum_{i=1\}^n} @<m>{\displaystyle\sum_{i=1\}^n}

== インライン命令
//label[inlineop]
#@# 場所ラベル定義

=== 書体
本文での……キーワード@<kw>{キーワード, keyword}@<fn>{kw}、太字@<b>{b太字}、イタリック@<i>{iイタリック}、等幅@<tt>{tt等幅}、強調@<strong>{strong強調}、強調@<em>{em強調}、下線@<u>{u下線}、等幅@<code>{code等幅}、等幅太字@<ttb>{ttb等幅太字}、等幅イタリック@<tti>{tti等幅イタリック}、網カケ@<ami>{amiアミ}、16進UTF文字指定@<uchar>{3042}、インラインアイコン@<icon>{inlineicon}

傍点@<embed>{@}<bou>{bou傍点}、ルビ@<embed>{@}<ruby>{愕然, がくぜん}、縦中横@<embed>{@}<tcy>{90}、はTeXでは現状、別パッケージが必要です。
#@# FIXME:TEXでの文字スタイル。外部パッケージが必要
#@# 傍点@<bou>{bou傍点}、
#@# ルビ@<ruby>{愕然, がくぜん}、
#@# 縦中横@<tcy>{90}、

 * kw, b, strong, emは同じ書体でよいでしょう。
 * tt、codeは同じ書体でよいでしょう。
 * amiはコードブロックの中で使うことを想定しています。

//footnote[kw][キーワードのカッコは太字にしないほうがいいのかなと思いつつあります（手元の案件では太字にしないよう挙動を変えてしまっているほうが多い）。]

 * 箇条書き内での……キーワード@<kw>{キーワード, keyword}、太字@<b>{b太字}、イタリック@<i>{iイタリック}、等幅@<tt>{tt等幅}、強調@<strong>{strong強調}、強調@<em>{em強調}、下線@<u>{u下線}、等幅@<code>{code等幅}、等幅太字@<ttb>{ttb等幅太字}、等幅イタリック@<tti>{tti等幅イタリック}、網カケ@<ami>{amiアミ}、16進UTF文字指定@<uchar>{3042}、インラインアイコン@<icon>{inlineicon}

//tsize[|latex|p{120mm}]
//table{
表内での……キーワード@<kw>{キーワード, keyword}、太字@<b>{b太字}、イタリック@<i>{iイタリック}、等幅@<tt>{tt等幅}、強調@<strong>{strong強調}、強調@<em>{em強調}、下線@<u>{u下線}、等幅@<code>{code等幅}、等幅太字@<ttb>{ttb等幅太字}、等幅イタリック@<tti>{tti等幅イタリック}、網カケ@<ami>{amiアミ}、16進UTF文字指定@<uchar>{3042}、インラインアイコン@<icon>{inlineicon}
//}

コードブロック内では対応装飾は減らしてよいと考えます。代わりにballoonが追加されます。

//emlist[キャプション内での……キーワード@<kw>{キーワード, keyword}、太字@<b>{b太字}、イタリック@<i>{iイタリック}、等幅@<tt>{tt等幅}、強調@<strong>{strong強調}、強調@<em>{em強調}、下線@<u>{u下線}、等幅@<code>{code等幅}、等幅太字@<ttb>{ttb等幅太字}、等幅イタリック@<tti>{tti等幅イタリック}、網カケ@<ami>{amiアミ}、16進UTF文字指定@<uchar>{3042}、インラインアイコン@<icon>{inlineicon}]{
コードブロック内での……
太字@<b>{b太字}
イタリック@<i>{iイタリック}
下線@<u>{u下線}
網カケ@<ami>{amiアミ}    @<balloon>{ふきだし説明}
//}


==={crossref} 参照
#@# FIXME:任意ラベルを使うと、EPUBチェックエラーになることがある？

 * 章番号：@<chap>{ch01}、@<chap>{appA}、@<chap>{part2}、@<chap>{bib}
 * 章題：@<title>{ch01}、@<title>{part2}、@<title>{appA}、@<title>{bib}
 * 章番号+題：@<chapref>{ch02}、@<chapref>{part2}、@<chapref>{appA}、@<chapref>{bib}
#@# FIXME:TeXで、部が実際のページではIIなのに参照では2になっているのはおかしい→i18n.ymlがおかしいせいか

節や項への参照はhdを使います。

 * @<hd>{ch02|ブロック命令}の@<hd>{ch02|ブロック命令|図}
 * @<hd>{ch02|crossref}
 * コラム参照 @<column>{ch03|column2}

他章への図表リスト参照の例です（@<list>{pre01|main1}、@<img>{pre01|fractal}、@<table>{pre01|tbl1}、@<list>{appA|lista-1}、@<img>{appA|puzzle}、@<table>{appA|taba-1}）。

なお、この「.」区切りなどのフォーマットは@<tt>{i18n.yml}あるいは@<tt>{locale.yml}でカスタマイズされ得る（format_number、format_number_header、format_number_without_chapter、format_number_header_without_chapter）ので、スタイルで固定化するのは避けるべきです。

labelで定義したラベルへの参照の例です。EPUBだと@<href>{#inlineop} TeXだと@<embed>{@}<href>{inlineop} 。互換性がないのは気味が悪いですね。
#@# FIXME:EPUB側にTeXのほうを寄せるようにRe:VIEWコードを直す
#@# FIXME:TeXではpagerefがほしい、ということがありそう。EPUBとの整合性を検討

=== 参考文献
参考文献@<tt>{bib.re}ファイルへの文献参照は、@<bib>{lins}とします。

=== 索引
@<hidx>{索引}@<hidx>{index}索引はTeXとIDGXML以外では妥当な動作を定義していません。idx@<hidx>{索引<<>>idx}は文中にも表示し、hidx@<hidx>{索引<<>>hidx}は文中からは隠した形の索引にします。読みは@<idx>{Mecab}があればそちらを使いますが、@<idx>{辞書ファイル}を直接定義することもできます。@<hidx>{!<>"$&()~=|,./\{\}?_[]*:;+%#()'`^}

idx, hidxいずれも=見出しの中には入れないようにし、後続の段落先頭にhidxで入れるように注意します（入れてしまうと目次などがおかしくなります）。
