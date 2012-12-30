# -*- coding: utf-8 -*-
require 'test_helper'
require 'review'

class INAOBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def test_all
    compiler = Compiler.new(INAOBuilder.new)
    chapter = Book::Chapter.new(nil, 1, "chap1", nil, StringIO.new)
    expected = <<-EOS
■見出し1（大見出し、節）
■■見出し2（中見出し、項）
■■■見出し3（小見出し、目）
　段落冒頭の字下げは、自動で行われます。改行は、（改行）このように自動で取り除かれます。
　通常の本文◆b/◆強調（ボールド）◆/b◆通常の本文◆i/◆斜体（イタリック）◆/i◆通常の本文◆cmd/◆インラインのコード◆/cmd◆通常の本文(注:注釈ですよ。)通常の本文Enter▲（←キーボードフォント）通常の本文◆ルビ/◆外村◆ほかむら◆/ルビ◆（←ルビ）。
◆quote/◆
引用です
◆/quote◆

◆column/◆
■■■■コラム見出し
　本文コラム
■■■■■コラム小見出し
　本文コラム
◆/column◆
EOS

    chapter.content = <<-EOS
= 見出し1（大見出し、節）
== 見出し2（中見出し、項）
=== 見出し3（小見出し、目）
段落冒頭の字下げは、自動で行われます。
改行は、（改行）
このように自動で取り除かれます。

通常の本文@<b>{強調（ボールド）}通常の本文@<i>{斜体（イタリック）}通常の本文@<tt>{インラインのコード}通常の本文(注:注釈ですよ。)通常の本文@<kbd>{Enter}（←キーボードフォント）通常の本文@<ruby>{外村,ほかむら}（←ルビ）。

//quote{
引用です
//}

====[column]コラム見出し
本文コラム

===== コラム小見出し
本文コラム

====[/column]


EOS
    assert_equal expected, compiler.compile(chapter)
  end
end

