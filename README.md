# Re:VIEW

[![Gem Version](https://badge.fury.io/rb/review.svg)](http://badge.fury.io/rb/review)
[![Build Status](https://secure.travis-ci.org/kmuto/review.svg)](http://travis-ci.org/kmuto/review)
[![Build status](https://ci.appveyor.com/api/projects/status/github/kmuto/review?svg=true)](https://ci.appveyor.com/project/kmuto/review)

Re:VIEW is an easy-to-use digital publishing system for paper books and ebooks.

## Supported Formats

![supported formats](./doc/images/review-generate.png)

Output formats Re:VIEW supports are:

* EPUB
* LaTeX
* InDesign (IDGXML)
* Markdown
* plain text (TOPBuilder Text Markup Language)

Re:VIEW uses its original format('Re:VIEW format') as source files.  See doc/format.md.

## Commands

There are two commands generate files directly.

* review-epubmaker: generate EPUB file.
* review-pdfmaker: generate PDF file using LaTeX(ptexlive).

And some useful commands.

* review-compile: compile Re:VIEW fomat files.
* review-vol: figure out size of Re:VIEW files.
* review-index: generate index with various format.
* review-preproc: preprocessor.

## Installation

Install gem yourself as:

    $ gem install review

Or build from source:

    $ git clone https://github.com/kmuto/review.git
    $ cd review
    $ rake install

Or add the `./bin` directory to your $PATH:

$ echo "export PATH=PATH_OF_REVIEW/bin:$PATH" >> ~/.profile

## Quick Start

```
$ review-init hello
$ cd hello
$ (... add and edit *.re file, config.yml and catalog.yml ...)
$ rake epub  ## generating EPUB
$ rake pdf   ## generating PDF(Requirement TeX)
```

For further information, see [doc/quickstart.md](https://github.com/kmuto/review/blob/master/doc/quickstart.md)

## Resources

|         | URL                                    |
|---------|----------------------------------------|
| Home    | http://reviewml.org                    |
| Project | https://github.com/kmuto/review/       |
| Gems    | https://rubygems.org/gems/review       |
| Wiki    | https://github.com/kmuto/review/wiki   |
| Bugs    | https://github.com/kmuto/review/issues |

### Documents

* Wiki pages: https://github.com/kmuto/review/wiki
* doc/* files (in English and Japanese)

### Issues tracker

* GitHub: https://github.com/kmuto/review

### Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## License

LGPL. See [COPYING](https://github.com/kmuto/review/blob/master/COPYING) file.

* jumoline.sty (test/sample-book/src/vendor/jumoline): The LaTeX Project Public License. See [LPPL](https://github.com/kmuto/review/blob/master/test/sample-book/src/vendor/jumoline/lppl.txt) file.

## Copyright

Copyright (c) 2006-2017 Minero Aoki, Kenshi Muto, Masayoshi Takahashi, Masanori Kado.
