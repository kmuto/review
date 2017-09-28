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
#@# キャプションなしはLaTeXだとエラーになることがわかった

実行例を示すとき用にはcmdを用意しています。いずれにせよ、商業書籍レベルでは必要なので用意しているものの、原稿レベルで書き手が使うコードブロックはほどほどの数に留めておいたほうがいいのではないかと思います。TeX版の紙面ではデフォルトは黒アミ。印刷によってはベタ黒塗りはちょっと怖いかもなので、あまり長々したものには使わないほうがいいですね。

//cmd{
$ @<b>{ls /}
//}

=== 図
採番・キャプション付きの図の貼り付けはimageを使用します（@<img>{ball}）。図版ファイルは識別子とビルダが対応しているフォーマットから先着順に探索されます。詳細については@<href>{https://github.com/kmuto/review/wiki/ImagePath, ImagePath}のドキュメントを参照してください。

@<fn>{madebygimp}
本当はimageのキャプションにfootnoteを付けたいのですが、TeXではエラーになりますね。厳しい……。

#@# //image[ball][ボール@<fn>{madebygimp}]{
//image[ball][ボール]{
//}

//footnote[madebygimp][GIMPのフィルタで作成。@<br>{}footnote内改行]

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
#@# ヘッダセルにはreviewthを付けているけれども、TeXスタイルで何も使っていないのはもったいないかも。アミかけるかベタ塗りにして白抜きにする？

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

画像にしておいて貼り付けたほうがよさそうな場合はimgtableを使います（@<table>{table}）。

//imgtable[table][ポンチ表]{
//}
