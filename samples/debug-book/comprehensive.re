= 包括的テスト文書

== はじめに

この文書では@<b>{Re:VIEW}の様々な機能を組み合わせて使用します。

=== 基本的なインライン要素

通常のテキストに加えて、@<i>{イタリック}、@<b>{太字}、@<code>{インラインコード}を使用できます。

== コードブロック

以下はRubyのサンプルコードです：

//list[ruby_sample][Rubyサンプル]{
class HelloWorld
  def initialize(name)
    @name = name
  end
  
  def greet
    puts "Hello, #{@name}!"
  end
end

hello = HelloWorld.new("World")
hello.greet
//}

@<list>{ruby_sample}のように参照できます。

== テーブル

//table[feature_comparison][機能比較表]{
項目	HTMLBuilder	HTMLRenderer	LATEXBuilder	LATEXRenderer
------------------------------------------------------------------
見出し	○	○	○	○
段落	○	○	○	○
リスト	○	○	○	○
テーブル	○	○	○	○
コードブロック	○	○	○	○
//}

== リスト

=== 順序なしリスト

 * 項目1
 ** サブ項目1-1
 ** サブ項目1-2
 * 項目2
 * 項目3

=== 順序ありリスト

 1. ステップ1
 2. ステップ2
 3. ステップ3

== 注意ブロック

//note[重要]{
これは重要な注意点です。複数行にわたって
記述することができます。
//}

//memo[補足]{
補足情報をメモブロックで提供できます。
//}

== まとめ

この文書では様々なRe:VIEW機能を組み合わせて使用しました。BuilderとRendererが同じ出力を生成することを確認します。