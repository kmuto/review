# -*- coding: utf-8 -*-
require 'test_helper'
require 'book_test_helper'
require 'review'

class INAOBuidlerTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def setup
    param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "stylesheet" => nil,  # for HTMLBuilder
    }
    ReVIEW.book.param = param
  end

  def test_all
    compiler = Compiler.new(INAOBuilder.new)
    mktmpbookdir do |dir, book, files|
      chapter = Book::Chapter.new(book, 1, "chap1", nil, StringIO.new)
      chapter.content = <<-EOS
= 見出し1（大見出し、節）
== 見出し2（中見出し、項）
=== 見出し3（小見出し、目）
段落冒頭の字下げは、自動で行われます。
改行は、（改行）
このように自動で取り除かれます。

通常の本文@<b>{強調（ボールド）}通常の本文@<i>{斜体（イタリック）}通常の本文@<tt>{インラインのコード}通常の本文@<fn>{1}通常の本文@<kbd>{Enter}（←キーボードフォント）通常の本文@<ruby>{外村,ほかむら}（←ルビ）。

//footnote[1][脚注]

//quote{
引用です
//}

====[column]コラム見出し
本文コラム

===== コラム小見出し
本文コラム

====[/column]

== 箇条書き
=== 通常の箇条書き
  * 連番箇条書き
  * 連番箇条書き
=== 連番箇条書き
  1. 連番箇条書き
  2. 連番箇条書き

== コマンド
//cmd[コマンドのタイトル]{
$ command foo
//}

=== 本文埋め込みコマンド（本文埋め込み版はWEB+DB PRESSでは未使用）
//cmd{
$ command foo
//}

== 表
//table[id][表のタイトル]{
項目1	項目2
-------------
内容1	内容2
内容1	内容2
//}

EOS

    expected = <<-EOS
■見出し1（大見出し、節）
■■見出し2（中見出し、項）
■■■見出し3（小見出し、目）
　段落冒頭の字下げは、自動で行われます。改行は、（改行）このように自動で取り除かれます。
　通常の本文◆b/◆強調（ボールド）◆/b◆通常の本文◆i/◆斜体（イタリック）◆/i◆通常の本文◆cmd/◆インラインのコード◆/cmd◆通常の本文◆注/◆脚注◆/注◆通常の本文Enter▲（←キーボードフォント）通常の本文◆ルビ/◆外村◆ほかむら◆/ルビ◆（←ルビ）。
◆quote/◆
引用です
◆/quote◆

◆column/◆
■■■■コラム見出し
　本文コラム
■■■■■コラム小見出し
　本文コラム
◆/column◆
■■箇条書き
■■■通常の箇条書き
・連番箇条書き
・連番箇条書き
■■■連番箇条書き
（1）連番箇条書き
（2）連番箇条書き
■■コマンド
◆list-white/◆
●コマンドのタイトル
$ command foo
◆/list-white◆
■■■本文埋め込みコマンド（本文埋め込み版はWEB+DB PRESSでは未使用）
◆list-white/◆
$ command foo
◆/list-white◆
■■表
◆table/◆
●表1.1　表のタイトル
◆table-title◆項目1	項目2
内容1	内容2
内容1	内容2
◆/table◆
EOS
      assert_equal expected, compiler.compile(chapter)
    end
  end

  def test_list
    compiler = Compiler.new(INAOBuilder.new)
    mktmpbookdir do |dir, book, files|
      chapter = Book::Chapter.new(book, 1, "chap1", nil, StringIO.new)
      chapter.content = <<-EOS
== リスト
@<list>{id}
//list[id][キャプション（コードのタイトル）]{
function hoge() {
    alert(foo);
    alert(bar);
}
//}

=== 本文埋め込みリスト
本文中で流れでコードを掲載するときに使用します。

//emlist{
function hoge() {
    alert(foo);@<comment>{こんな風にコメントがつけられます}
}
//}

このように、上下に本文が入ります。

本文から一連の流れで読んでもらうことができますが、コードがページをまたぐ可能性がございます。
EOS
      expected = <<-EOS
■■リスト
　リスト1.1
◆list/◆
●リスト1.1　キャプション（コードのタイトル）
function hoge() {
    alert(foo);
    alert(bar);
}
◆/list◆
■■■本文埋め込みリスト
　本文中で流れでコードを掲載するときに使用します。
◆list/◆
function hoge() {
    alert(foo);◆comment/◆こんな風にコメントがつけられます◆/comment◆
}
◆/list◆
　このように、上下に本文が入ります。
　本文から一連の流れで読んでもらうことができますが、コードがページをまたぐ可能性がございます。
EOS
      assert_equal expected, compiler.compile(chapter)
    end
  end

  def test_image
    compiler = Compiler.new(INAOBuilder.new)
    mktmpbookdir do |dir, book, files|
      chapter = Book::Chapter.new(book, 1, "chap1", nil, StringIO.new)
      chapter.content = <<-EOS
= 図
@<img>{id}
//image[id][図のタイトル]{
ダミー
//}
EOS
      expected = <<-EOS
■図
　図1.1
●図1.1　図のタイトル
ダミー
EOS
      assert_equal expected, compiler.compile(chapter)
    end
  end

  def test_table
    compiler = Compiler.new(INAOBuilder.new)
    mktmpbookdir do |dir, book, files|
      chapter = Book::Chapter.new(book, 1, "chap1", nil, StringIO.new)
      chapter.content = <<-EOS
== 表
@<table>{id}
//table[id][表のタイトル]{
項目1	項目2
-------------
内容1	内容2
内容1	内容2
//}
EOS
      expected = <<-EOS
■■表
　表1.1
◆table/◆
●表1.1　表のタイトル
◆table-title◆項目1	項目2
内容1	内容2
内容1	内容2
◆/table◆
EOS
      assert_equal expected, compiler.compile(chapter)
    end
  end

  def test_listnum
    compiler = Compiler.new(INAOBuilder.new)
    mktmpbookdir do |dir, book, files|
      chapter = Book::Chapter.new(book, 1, "chap1", nil, StringIO.new)
      chapter.content = <<-EOS
== リスト
@<list>{id}
//listnum[id][キャプション（コードのタイトル）]{
function hoge() {
    alert(foo);
    alert(bar);
}
//}
EOS
      expected = <<-EOS
■■リスト
　リスト1.1
◆list/◆
●リスト1.1　キャプション（コードのタイトル）
 1 function hoge() {
 2     alert(foo);
 3     alert(bar);
 4 }
◆/list◆
EOS
      assert_equal expected, compiler.compile(chapter)
    end
  end
end
