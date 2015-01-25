# Re:VIEW Quick Start Guide

Re:VIEW is a toolset to convert from Re:VIEW format documents into various formats.

Re:VIEW uses original lightweight markup language like EWB, RD or Wiki.  Its syntax is simple but powerful for writing IT documents.
When you write your documents in Re:VIEW format, you can convert them with Re:VIEW tools into LaTeX, HTML, EPUB, InDesign, Text, and so on.

Re:VIEW is free software under the terms of the GNU Lesser General Public License Version 2.1, so you can use, modify and redistribute it. This license has no relations with your documents using Re:VIEW, so your documents are not forced to use this license. When you want to distribute Re:VIEW software itself or the system including Re:VIEW software, you should read COPYING file carefully.

This article describes how to setup Re:VIEW and use it.

## Set up Re:VIEW

Re:VIEW is a software in Ruby and worked in Linux/Unix, Mac OS X, and Cygwin. You can install Re:VIEW with RubyGems, Git or Subversion.

Note that Re:VIEW format is tagged text file, so you can write it on any editors and OSes.

### using RubyGmes

Re:VIEW is released as RubyGems.

* https://rubygems.org/gems/review

Add this line to your application's Gemfile:

```Gemfile
gem 'review'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```bash
$ gem install review
```

### using Git

You can get latest Re:VIEW sources from GitHub.

```bash
$ git clone git://github.com/kmuto/review.git
```

You can use Re:VIEW to add `review/bin` directory to `$PATH` variable.

You can update the sources as follows:

```bash
$ git pull
```

### using Subversion

For non git users and environments, Re:VIEW is also distributed with Subversion.

```bash
$ svn co https://kmuto.jp/svn/review/trunk review
```

You can use Re:VIEW to add `review/bin` directory to `$PATH` variable.

You can update the sources as follows:

```bash
$ svn up
```

# writing Re:VIEW documents and converting them

After setup, you can use `review-init` command to generate Re:VIEW project directory.

To generate `hello` project:

```bash
$ review-init hello
$ cd hello
$ ls hello
Rakefile     catalog.yml  config.yml   hello.re     images/      layouts/     sty/         style.css
```

In `hello` directory, many files are generated. `*.re` files are Re:VIEW format file.
If you make `hello` project, a file `hello.re` is generated.

`catalog.yml` file is a catalog of Re:VIEW format files.

```bash
$ cat catalog.yml
PREDEF:

CHAPS:
  - hello.re

APPENDIX:

POSTDEF:
```

The first item in CHAPS is the first chapter, and the second item (if you add) is the second chapter. PREDEF is for front matter, APPENDIX is for appendix, and POSTDEF is for back matter.

If you create new `*.re` files as new chapters, you should add the name of files into `catalog.yml`.

Now you can edit `hello.re`. A simple example of Re:VIEW format text is as follows.


```review
= my first Re:VIEW

//lead{
"Hello, Re:VIEW."
//}

== What's Re:VIEW

@<b>{Re:VIEW} is a converter from simple markup documents into various formats.

You can generate documents as follows:

 * text with tagging
 * LaTeX
 * HTML
 * XML

You can install Re:VIEW with:

 1. RubyGems
 2. Git
 3. Subversion

For more information, see @<tt>{https://github.com/kmuto/review/wiki/}.
```

You should use UTF-8 as encodings in text files.

To convert hello.re, you can use `review-compile` command.

```bash
$ review-compile --target html hello.re > hello.html  ## generating HTML
$ review-compile --target latex hello.re > hello.tex  ## generating LaTeX
$ review-compile --target idgxml hello.re > hello.xml ## generating XML for InDesing
```

You can convert all `*.re` files in `catalog.yml` with `-a` option.

```
$ review-compile --target html -a  ## convert all files into HTML
```

You can get HTML file as follows:

```html
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
  <meta http-equiv="Content-Style-Type" content="text/css" />
  <link rel="stylesheet" type="text/css" href="style.css" />
  <meta name="generator" content="Re:VIEW" />
  <title>my first Re:VIEW</title>
</head>
<body>
<h1><a id="h1"></a>第1章　my first Re:VIEW</h1>
<div class="lead">
<p>&quot;Hello, Re:VIEW.&quot;</p>
</div>

<h2><a id="h1-1"></a>1.1　What's Re:VIEW</h2>
<p><b>Re:VIEW</b> is a converter from simple markup documents into various formats.</p>
<p>You can generate documents as follows:</p>
<ul>
<li>text with tagging</li>
<li>LaTeX</li>
<li>HTML</li>
<li>XML</li>
</ul>
<p>You can install Re:VIEW with:</p>
<ol>
<li>RubyGems</li>
<li>Git</li>
<li>Subversion</li>
</ol>
<p>For more information, see <tt>https://github.com/kmuto/review/wiki/</tt>.</p>

</body>
</html>
```

For more information about Re:VIEW format, see [format.rdoc](https://github.com/kmuto/review/blob/master/doc/format.rdoc).

review-compile and other commands in Re:VIEW has `--help` option to output help.  `review-compile` has many options, so you may see them.

If you don't want to type `--target` every time, you can use symbolic links to `review-compile`. You can use new commands `review2html` and so on.

```bash
$ cd path/to/review/bin
$ ln -s review-compile review2text
$ ln -s review-compile review2html
$ ln -s review-compile review2latex
$ ln -s review-compile review2idgxml
```

## preprocessor and other commands

With Re:VIEW tags such as `#@mapfile`, `#@maprange` and `#@mapoutput`, you can include content of files or result of command execution. To do so, you use `review-preproc` command.

```bash
$ review-preproc hello_orig.re > hello.re   ## redirect stdout into file

## also:
$ review-preproc --replace hello.re   ## update files overwriting
```

You can use `review-vol` command to know the volume of the document.

```bash
$ review-vol
```

You can also use `review-index` command to generate header list.

```bash
$ review-index --level <heading level> -a
```

## generating PDF and EPUB

You can generate PDF and EPUB as:

```bash
$ review-pdfmaker config.yml  ## generate PDF
$ review-epubmaker config.yml ## generate EPUB
```

To generate PDF, you should install TeXLive 2012 or later.  To generate EPUB, you should install zip command.
When you want to use MathML, you should install [MathML library](http://www.hinet.mydns.jp/?mathml.rb)

`review-pdfmaker` and `review-epubmaker` need `config.yml`, configuration YAML files. There is a sample YAML file [sample.yml](https://github.com/kmuto/review/blob/master/doc/sample.yml) in the same directory of this document.


## Copyright

The original author of Re:VIEW is Minero Aoki. The current maintainer is Kenshi Muto(@kmuto), and committers are Masayoshi Takahashi and Masanori Kado (2015/01).

If you want to report bugs and patches, or to get more information, see:

* https://github.com/kmuto/review/wiki
