= 見出し
以下を実行
//emlist{
./bin/review-compile --hdnumberingmode test.re --target=html
}
== 節１

== 節２

==[column]コラム

== 節３

ソースコードの引用

//source[/hello/world.rb]{
 puts "hello world!"
//}

■行番号付きキャプションなしリスト
//emlistnum{
hoge
fuge
//}

■行番号付きキャプションありリスト
//listnum[hoge][ほげ]{
hoge
fuge
//}

ほげは@<list>{hoge}でもわかるとおり

■本文中でのソースコード引用
擬似コード内のの@<code>{p = obj.ref_cnt}では…

■参考文献の参照方法
…がしられています( @<bib>{lins} )


//emlist{
hoge
//}
