# Re:VIEW Format Guide

The document is a brief guide for Re:VIEW markup syntax.

Re:VIEW is based on EWB of ASCII (now KADOKAWA), influenced RD and other Wiki system's syntax.

This document explains about the format of Re:VIEW 2.0.


## Paragraph

Paragraphs are separated by an empty line.

Usage:

```
This is a paragraph, paragraph,
and paragraph.

Next paragraph here is ...
```

Two empty lines or more are same as one empty line.

## Chapter, Section, Subsection (headings)

Chapters, sections, subsections, subsubsections use `=`, `==`, `===`, `====`, `=====`.
You should add one or more spaces after `=`.

Usage:

```review
= 1st level (chapter)

== 2nd level (section)

=== 3rd level (subsection)

==== 4th level

===== 5th level
```

Headings should not have any spaces before title; if line head has space, it is as paragraph.

You should add emply lines between Paragraphs and Headings.

## Column

`[column]` in heading are column's caption.

Usage:

```review
===[column] Compiler-compiler
```

`=` and `[column]` should be closed to.  Any spaces are not permitted.

Columns are closed with next headings.

```
== head 01

===[column] a column

== head 02 and the end of  'a column'
```

If you want to close column without headings, you can use `===[/column]`

Usage:

```review
===[column] Compiler-compiler

Compiler-compiler is ...

===[/column]

blah, blah, blah (this is paragraphs outside of the column)
```

There are some more options of headings.

* `[nonum]` : no numbering, but add it into TOC (Table of Contents).
* `[nodisp]` : not display in document, only in TOC.
* `[notoc]` :  no numbering, not in TOC.

## Itemize

Itemize (ul in HTML) use ` *` (one space char and asterisk).

Nested itemize is like ` **`, ` ***`.

Usage:

```
* 1st item
** nested 1st item
* 2nd item
** nested 2nd item
* 3rd item
```

In itemize, you must write one more space character at line head.
When you use `*` without spaces in line head, it's just paragraph.

You should add emply lines between Paragraphs and Itemize (same as Ordered and Non-Orderd).

## Ordered itemize

Ordered itemize (ol in HTML)  use ` 1. ...`, ` 2. ...`, ` 3. ...`.
They aren't nested.

Usage:


```
1. 1st condition
2. 2nd condition
3. 3rd condition
```

The value of Number is ignored.

```
1. 1st condition
1. 2nd condition
1. 3rd condition
```

You must write one more space character at line head like itemize.

## Definition List

Definition list (dl in HTML) use `:` and indented lines.

Usage:

```review
: Alpha
    RISC CPU made by DEC.
: POWER
    RSIC CPU made by IBM and Motolora.
    POWER PC is delivered from this.
: SPARC
    RISC CPU made by SUN.
```

`:` in line head is not used as a text.
The text after `:` is as the term (dt in HTML).

In definition list, `:` at line head allow space characters.
After dt line, space-indented lines are descriptions(dd in HTML).

You can use inline markup in texts of lists.

## Code list

Code list like source codes is `//list`. If you don't need numbers, you can use ``em`` prefix (as embedded). If you need line numbers, you can use ``num`` postfix.  So you can use four types of lists.

* ``//list[ID][caption][language]{ ... //}``
  * normal list. language is optional.
* ``//listnum[ID][caption][language]{ ... //}``
  * normal list with line numbers. language is optional.
* ``//emlist[caption][language]{ ... //}``
  * list without caption counters. caption and language are optional.
* ``//emlistnum[caption][language]{ ... //}``
  * list with line numbers without caption counters. caption and language are optional.

Usage:

```review
//list[main][main()][c]{    ←ID is `main`, caption is `main()`
int
main(int argc, char **argv)
{
    puts("OK");
    return 0;
}
//}
```

Usage:

```review
//listnum[hello][hello world][ruby]{
puts "hello world!"
//}
```

Usage:

```review
//emlist[][c]{
printf("hello");
//}
```

Usage:

```review
//emlistnum[][ruby]{
puts "hello world!"
//}
```


You can use inline markup in blocks.

When you refer a list like `see list X`, you can use an ID in `//list`
such as `@<list>{main}`.


### Quoting source code

`//source` is for quoting source code. filename is mandatory.

Usage:

```review
//source[/hello/world.rb]{
puts "hello world!"
//}
```

`//source` and `//emlist` with caption is not so different.
You can use them with different style with CSS (in HTML) and style file (in LaTeX).

`//source` can be referred same as the list.

Usage:

```
When you ..., see @<list>{hello}.
```

## Inline source code

You can use `@<code>{...}` in inline context.

Usage:

```review
@<code>{p = obj.ref_cnt}
```

## Shell session

When you want to show command line operation, you can use `//cmd{ ... //}`.
You can use inline commands in this command.

Usage:

```
//cmd{
$ @<b>{ls /}
//}
```

You can use inline markup in `//cmd` blocks.

## Figure

You can use `//image{ ... //}` for figures.
You can write comments or Ascii art in the block as an alternative description.
When publishing, it's simply ignored.


Usage:

```
//image[unixhistory][a brief history of UNIX-like OS]{
          System V
            +----------- SVr4 --> Commercial UNIX（Solaris, AIX, HP-UX, ...）
V1 --> V6 --|
            +--------- 4.4BSD --> FreeBSD, NetBSD, OpenBSD, ...
          BSD

            --------------> Linux
//}
```

When you want to refer images such as "see figure 1.", you can use
inline reference markup like `@<img>{unixhistory}`.

When you want to use images in paragraph or other inline context, you can use `@<icon>`.

### Finding image pathes

The order of finding image is as follows.  The first matched one is used.

```
1. <imgdir>/<builder>/<chapid>/<id>.<ext>
2. <imgdir>/<builder>/<chapid>-<id>.<ext>
3. <imgdir>/<builder>/<id>.<ext>
4. <imgdir>/<chapid>/<id>.<ext>
5. <imgdir>/<chapid>-<id>.<ext>
6. <imgdir>/<id>.<ext>
```

* ``<imgdir>`` is `images` as default.
* ``<builder>`` is a builder (target) name to use.  When you use review-comile commmand with ``--target=html``, `<imagedir>/<builder>` is `images/html`.
* ``<chapid>`` is basename of *.re file.  If the filename is `ch01.re`, chapid is `ch01`.
* ``<id>`` is the ID of the first argument of `//image`.  You should use only printable ASCII characters as ID.
* ``<ext>`` is file extensions of Re:VIEW.  They are different by the builder you use.

## Images without caption counter

`//indepimage[filename][caption]` makes images without caption counter.
caption is optional.

Usage:

```
//indepimage[unixhistory2]
```

Note that there are similar markup `//numberlessimage`, but it is deprecated.


## Figures with graph tools

Re:VIEW generates image files using graph tool with command `//graph[filename][commandname][caption]`. The caption is optional.

Usage: using with Gnuplot

```
//graph[sin_x][gnuplot]{
plot sin(x)
//}
```

You can use `graphviz`, `gnuplot`, `blockdiag`, `aafigure` as the command name.
Before using these tools, you should installed them.

## Tables

The markup of table is `//table[ID][caption]{ ... //}`
You can separate header and content with `------------`.

The columns are splitted by TAB character. When the first character in the column is `.`, the character is removed.  If you want to write `.` at the first, you should write `..`.

When you want to use an empty column, you write `.`.

Usage:

```
//table[envvars][Important environment varialbes]{
Name            Comment
-------------------------------------------------------------
PATH            Directories where commands exist
TERM            Terminal. ex: linux, kterm, vt100
LANG            default local of users. ja_JP.eucJP and ja_JP.utf8 are popular in Japan
LOGNAME         login name of the user
TEMP            temporary directory. ex: /tmp
PAGER           text viewer on man command. ex: less, more
EDITOR          default editor. ex: vi, emacs
MANPATH         Directories where sources of man exist
DISPLAY         default display of X Window System
//}
```

When you want to write "see table X", you can write `@<table>{envvars}`.

You can use inline markup in the tables.

## Quoting text

You can use `//quote{ 〜 //}` as quotations.

Usage:

```
//quote{
Seeing is believing.
//}
```

You can use inline markup in quotations.


## Footnotes

You can use `//footnote` to write footnotes.

Usage:

```
You can get the packages from support site for the book.@<fn>{site}
You should get and install it before reading the book.
//footnote[site][support site of the book: http://i.loveruby.net/ja/stdcompiler ]
```

`@<fn>{site}` in source are replaced by footnote marks, and the phrase "support site of .."
is in footnotes.

Note that In LATEXBuilder, you should use `footnotetext` option to use `@<fn>{...}` in columns and tables.

### --footnotetext option

When you want to use `footnotetext` option, you can add `--footnotetext` with `params` in config.yml.
With this option, you can use footnote in tables and short notes.

Note that there are some constraints that (because of normal footnote )

And you cannot use footnote and footnotemark/footnotetext at the same time.

Note that with this option, Re:VIEW use footnotemark and footnotetext instead of normal footnote.
There are some constraints to use this option.
You cannot use footnote and footnotemark/footnotetext at the same time.

## Bibliography

When you want to use a bibliography, you should write them in the file `bib.re`.

```
//bibpaper[cite][caption]{..comment..}
```

The comment is optional.

```
//bibpaper[cite][caption]
```

Usage:

```
//bibpaper[lins][Lins, 1991]{
Refael D. Lins. A shared memory architecture for parallel study of
algorithums for cyclic reference_counting. Technical Report 92,
Computing Laboratory, The University of Kent at Canterbury , August
1991
//}
```

When you want to refer some references, You should write as:

Usage:

```
… is the well-known project.(@<bib>{lins})
```

## Lead sentences

lead sentences are `//lead{ ... //}`.
You can write as `//read{ ... //}`.

Usage:

```
//lead{
In the chapter, I introduce brief summary of the book,
and I show the way how to write a program in Linux.
//}
```

## TeX equations

You can use `//texequation{ ... //}` to insert mathematical equations of LaTeX.

Usage:

```
//texequation{
\sum_{i=1}^nf_n(x)
//}
```

## Spacing

`//noindent` is a tag for spacing.


* `//noindent` : ingore indentation immediately following line. (in HTML, use noindent class)


`//linebreak` and `//pagebreak` will be obsoleted.

## Comments

If you want to write some comments that do not output in the document, you can use comment notation `#@#`.

Usage:

```
#@# Must one empty line
```

If you want to write some warnings, use `#@warn(...)`.

Usage:

```
#@warn(TBD)
```

When you want to write comments in the output document, use `//comment` and `@<comment>` with the option `--draft` of review-compile command.

Usage:

```
@<comment>{TODO}
```

## Raw data block

When you want to write non-Re:VIEW line, use `//raw`.

Usage:

```
//raw[|html|<div class="special">\nthis is a special line.\n</div>]
```

In above line, `html` is a builder name that handle raw data.
You can use `html`, `latex`, `idgxml` and `top` as builder name.
You can specify multiple builder names with separator `,`.
`\n` is translated into newline(U+000A).

Output:

(In HTML:)

```
<div class="special">
this is a special line.
</div>
```

(In other formats, it is just ignored.)

Note: `//raw` and `@<raw>` may break structured document easily.

## Other syntax

In Re:VIEW, you can add your customized blocks.  So you can define
special block for some books.

* `//prototype` : function prototype. It's used in the book `Futu no Linux programming`.
* `//type` : type definition. It's used in the book `Futu no Haskell programming`.

You can define customized block in the file `review-ext.rb`.

Usage:

```ruby
# review-ext.rb
ReVIEW::Compiler.defblock :foo, 0..1
class ReVIEW::HTMLBuilder
  def foo(lines, caption = nil)
    puts lines.join(",")
  end
end
```

You can add the syntax as below:

```
//foo{
A
B
C
//}
```

```
# Result
A,B,C
```


## Syntax in paragraph (Inline Markups)

```
@<list>{program}:: `List 1.5`
@<img>{unixhistory}:: `Figure 1.3`
@<table>{ascii}:: `Table 1.2`
@<fn>{site}:: footnote number
@<kw>{Credential, credential}:: keyword.
@<chap>{advanced}:: chapter number like `Chapter 17`
@<title>{advanced}:: title of the chapter
@<chapref>{advanced}:: a chapter number and chapter title like `Chapter 17. advanced topic`
@<bou>{appropriate}:: bou-ten.
@<ruby>{Matsumoto, Matz}:: ruby
@<ami>{point}:: ami-kake (shaded text)
@<b>{Please}:: bold
@<i>{Please}:: italic
@<strong>{Please}:: strong(emphasis)
@<em>{Please}:: another emphasis
@<tt>{foo($bar)}:: teletype (monospaced font)
@<tti>{FooClass}:: teletype (monospaced font) and italic
@<ttb>{BarClass}:: teletype (monospaced font) and bold
@<u>{AB}:: underline
@<br>{}::  linebreak in paragraph
@<m>{a + \alpha}:: TeX inline equation
@<icon>{samplephoto}:: inline image
@<uchar>{2460}:: Unicode code point
@<href>{http://www.google.com/, google}:: hyper link(URL)
@<raw>{|html|<span>ABC</span>}:: inline raw data inline. `\}` is `}` and `\\` is `\`.
```

## Tags for Authors (pre-processor commands)

These tags are used in the output document. In contrast,
tags as below are not used in the output document,  used
by the author.

```
#@#:: Comments. All texts in this line are ignored.
#@warn(...):: Warning messages. The messages are showed when pre-process.
#@require, #@provide:: Define dependency with keywords.
#@mapfile(filename) ... #@end:: Insert all content of files.
#@maprange(filename, range name) ... #@end:: Insert some area in content of files.
#@mapoutput(command) ... #@end:: Execute command and insert their output.
```

## HTML/LaTeX layout

`layouts/layout.html.erb` and `layouts/layout.tex.erb` are used as layout file.
You can use ERb tags in the layout files.


Sample layout file(layout.html.erb):

```html
<html>
  <head>
    <title><%= title %></title>
  </head>
  <body>
    <%= body %>
    <hr/>
  </body>
</html>
```

## Part title (in TOC)

In version 1.2 or before, you can define the parts in PART file.
PART file correspond with chapters in CHAPS file.

Usage:

```
CHAPS:
  intro.re

  start.re

  end.re
```

```
PART:
  (empty line)
  start section
  last section
```

In version 1.3 or after, you can use catalog.yml file.
For more information of catalog.yml, see Re:VIEW catalog file guide(catalog.md).

## Referring headings

`@<hd>` generate referred section title and section number.
You can use deeper section with separator `|`.

Usage:

```
@<hd>{intro|first section}
```

If section title is unique, `|` is not needed.

```
@<hd>{first section}
```

If you want to refer another chapter (file), you should add the ID of chapter.

Usage:

```
@<hd>{preface|Introduction|first section}
```

When section has the label, you can use the label.

```
=={intro} Introduction
:
=== first section
:
@<hd>{intro|first section}
```


### Heading of columns

You can refer the heading of a column with `@<column>`.

Usage:

```
@<column>{The usage of Re:VIEW}
```

You can refer labels.

```
==[column]{review-application} The application of Re:VIEW
:
@<column>{review-application}
```

## Links

You can add a hyperlink with `@<href>` and `//label`.
Notation of the markup is `@<href>{URL, anchor}`. If you can use URL itself
as anchor, use `@<href>{URL}`.
If you want to use `,` in URL, use `\,`.

Usage:

```
@<href>{http://github.com/, GitHub}
@<href>{http://www.google.com/}
@<href>{#point1, point1 in document}
@<href>{chap1.html#point1, point1 in document}
//label[point1]
```

## Internationalization (i18n)

Re:VIEW support I18N of some text like `Chapter`, `Figure`, and `Table`.
Current default language is Japanese.


You add the file locale.yml in the project directory.

Sample local.yml file:

```yaml
locale: en
```

If you want to customize texts, overwrite items.
Default locale configuration file is in lib/review/i18n.yml.

Sample local.yml file:

```yaml
locale: en
image: Fig.
table: Tbl.
```

### Re:VIEW custom format

In locale.yml, you can use these Re:VIEW custom format.

* ``%pA``: Alphabet (A, B, C, ...)
* ``%pa``: alphabet (a, b, c, ...)
* ``%pR``: Roman Number (I, II, III, ...)
* ``%pr``: roman number (i, ii, iii, ...)
