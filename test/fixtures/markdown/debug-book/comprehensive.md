# 包括的テスト文書

## はじめに

この文書では**Re:VIEW**の様々な機能を組み合わせて使用します。

### 基本的なインライン要素

通常のテキストに加えて、*イタリック*、**太字**、`インラインコード`を使用できます。

## コードブロック

以下はRubyのサンプルコードです：

<div id="ruby_sample">

**Rubyサンプル**

```
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
```

</div>

<span class="listref"><a href="./comprehensive.html#ruby_sample">リスト1.1</a></span>のように参照できます。

## テーブル

<div id="feature_comparison">

**機能比較表**

| 項目 | HTMLBuilder | HTMLRenderer | LATEXBuilder | LATEXRenderer |
| :-- | :-- | :-- | :-- | :-- |
| 見出し | ○ | ○ | ○ | ○ |
| 段落 | ○ | ○ | ○ | ○ |
| リスト | ○ | ○ | ○ | ○ |
| テーブル | ○ | ○ | ○ | ○ |
| コードブロック | ○ | ○ | ○ | ○ |

</div>

## リスト

### 順序なしリスト

* 項目1
  * サブ項目1-1
  * サブ項目1-2

* 項目2
* 項目3

### 順序ありリスト

1. ステップ1
2. ステップ2
3. ステップ3

## 注意ブロック

<div class="note">

**重要**

これは重要な注意点です。複数行にわたって 記述することができます。


</div>

<div class="memo">

**補足**

補足情報をメモブロックで提供できます。


</div>

## まとめ

この文書では様々なRe:VIEW機能を組み合わせて使用しました。BuilderとRendererが同じ出力を生成することを確認します。

