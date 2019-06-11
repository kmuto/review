#!/usr/bin/ruby
require 'rubygems'
require 'unicode/eaw'

def add_space?(line1, line2, lang, lazy = nil)
  # https://drafts.csswg.org/css-text-3/#line-break-transform

  # 1. If the character immediately before or immediately after the
  # segment break is the zero-width space character (U+200B), then the
  # break is removed, leaving behind the zero-width space.

  # 2. Otherwise, if the East Asian Width property [UAX11] of both the
  # character before and after the segment break is Fullwidth, Wide,
  # or Halfwidth (not Ambiguous), and neither side is Hangul, then the
  # segment break is removed.

  # 3. Otherwise, if the writing system of the segment break is
  # Chinese, Japanese, or Yi, and the character before or after the
  # segment break is punctuation or a symbol (Unicode general category
  # P* or S*) and has an East Asian Width property of Ambiguous, and
  # the character on the other side of the segment break is Fullwidth,
  # Wide, or Halfwidth, and not Hangul, then the segment break is
  # removed.

  # 4. Otherwise, the segment break is converted to a space (U+0020).
  tail = line1[-1]
  head = line2[0]
  space = true

  # 条件1はstripされているので無視できるものとする
  # 条件2
  if %i[F W H].include?(Unicode::Eaw.property(tail)) && %i[F W H].include?(Unicode::Eaw.property(head)) && tail !~ /\p{Hangul}/ && head !~ /\p{Hangul}/
    space = nil
  end

  if %w[ja zh zh_CN zh_TW yi].include?(lang)
    # 条件3
    if (%i[F W H].include?(Unicode::Eaw.property(tail)) && tail !~ /\p{Hangul}/ && (head =~ /\p{P}/ || head =~ /\p{S}/ || Unicode::Eaw.property(head) == :A)) ||
       (%i[F W H].include?(Unicode::Eaw.property(head)) && head !~ /\p{Hangul}/ && (tail =~ /\p{P}/ || head =~ /\p{S}/ || Unicode::Eaw.property(tail) == :A))
      space = nil
    end

    # lazyなやり方。
    # 条件3だとabc→あい みたいなのが「abc あい」になる。FWHな文字→何か または 何か→FWHな文字 なら原則つなげるほうがよいのではないかという考え方
    if lazy &&
       (%i[F W H].include?(Unicode::Eaw.property(tail)) && tail !~ /\p{Hangul}/) ||
       (%i[F W H].include?(Unicode::Eaw.property(head)) && head !~ /\p{Hangul}/)
      space = nil
    end
  end
  space
end

def create_paragraph(src, lang, lazy = nil)
  lines = src.split("\n")
  0.upto(lines.size - 2) do |n|
    if add_space?(lines[n], lines[n + 1], lang, lazy)
      lines[n] += ' '
    end
  end

  lines.join
end

# Re:VIEWでは段落はlines配列で入ってくる。すでにparagraph単位になっており、行頭行末のスペースは除去されている。
# 各ビルダごとのinline_compile済み & エスケープ済みになっているのがかなり厄介

src = <<-EOS
Here is an English paragraph
that I know.
Yes.
EOS
puts '期待 : Here is an English paragraph that I know. Yes.'
puts '結果1: ' + create_paragraph(src, 'ja')
puts '結果2: ' + create_paragraph(src, 'ja', true)

src = <<-EOS
Here is an English paragraphあα조선
글いthat
EOS
puts '期待 : Here is an English paragraphあα조선 글いthat'
puts '結果1: ' + create_paragraph(src, 'ja')
puts '結果2: ' + create_paragraph(src, 'ja', true)

src = <<-EOS
Here is an English paragraphあα
いthat.
お_
あ>
れ
EOS
puts '期待 : Here is an English paragraphあαいthat.お_あ>れ (でいいんだろうか?)'
puts '結果1: ' + create_paragraph(src, 'ja')
puts '結果2: ' + create_paragraph(src, 'ja', true)

src = <<-EOS
这个段落是呢么长，
在一行写不行。最好
用三行写。
EOS
puts '期待 : 这个段落是呢么长，在一行写不行。最好用三行写。'
puts '結果1: ' + create_paragraph(src, 'ja')
puts '結果2: ' + create_paragraph(src, 'ja', true)

src = <<-EOS
段落abc
うーん？
def?
む1
に
EOS
puts '期待 : 段落abcうーん？def?む1に (abcのあとにスペースが正しい?)'
puts '結果1: ' + create_paragraph(src, 'ja')
puts '結果2: ' + create_paragraph(src, 'ja', true)

src = <<-EOS
<b>日</b>
<i>本語</i>
段落<b>日本語</b>
段落<b>English</b>
<i>Man</i>
うーん\\textbf{日本語}
あ\\textbf{English}
\\textbf{That}
1
個
★Alphabet☆
★Alphabet☆
あ
★Alphabet☆
dice
★日☆
★本語☆
EOS
puts '期待 : <b>日</b><i>本語</i>段落<b>日本語</b>段落<b>English</b> <i>Man</i>うーん\\textbf{日本語}あ\\textbf{English} \\textbf{That} 1個★Alphabet☆ ★Alphabet☆あ★Alphabet☆ dice★日☆★本語☆ (スペース位置悩み)'
puts '結果1: ' + create_paragraph(src, 'ja')
puts '結果2: ' + create_paragraph(src, 'ja', true)
