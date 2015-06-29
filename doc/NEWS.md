# Version 1.6.0

## In general
* Stop supporting Ruby 1.8.7
* Enable to set default language for code highlighting ([#403])
* Use I18n in inline ``@<hd>`` chap ([#420])
* Support highlighting and lang option in ``//source``

## Bug Fix
* Fix ``@<hd>`` to detect the target header-index in the middle of indexes ([#400])
* Fix epubmaker to escape pathname includes whitespace ([#398])
* Fix ``Builder#get_chap`` to return formatted appendix name correctly ([#405])
* Fix missing listing name when using syntax highlighting ([#418])
* Fix i18n to merge settings correctly ([#423])
* Fix epubmaker to match coverimage strictly ([#417])
* Fix htmlversion when epubversion == 3 ([#433])

## Commands

### review-init
* Add option to create locale.yml ([#425])

## Builders and Makers

### htmlbuilder
* Markup section number by span ([#415])

### latexbuilder
* Support ``config["conver"]``

### pdfmaker
* Support file insertion (same as EPUBMaker)

### epubmaker
* Add ``toc`` property to config.yml ([#413])

## Code contributors
* [@keiji](https://github.com/keiji)
* [@orangain](https://github.com/orangain)
* [@akinomurasame](https://github.com/akinomurasame)
* [@krororo](https://github.com/krororo)
* [@masarakki](https://github.com/masarakki)

[#398]: https://github.com/kmuto/review/issues/398
[#400]: https://github.com/kmuto/review/issues/400
[#405]: https://github.com/kmuto/review/issues/405
[#403]: https://github.com/kmuto/review/issues/403
[#413]: https://github.com/kmuto/review/issues/413
[#415]: https://github.com/kmuto/review/issues/415
[#417]: https://github.com/kmuto/review/issues/417
[#418]: https://github.com/kmuto/review/issues/418
[#420]: https://github.com/kmuto/review/issues/420
[#423]: https://github.com/kmuto/review/issues/423
[#425]: https://github.com/kmuto/review/issues/425
[#433]: https://github.com/kmuto/review/issues/433


# version 1.5.0
## Notice
To support language parameter for syntax highlighting, if you use review-ext.rb to extend code block markup such as ``//list`` and ``//emlist``, you should fix it (if you don't use review-ext.rb, you don't have to do anything).

## In general
* Add default properties in config.yml
* Fix appendix format with ``@<hd>``.
* Fix index error in shallow column.
* Add more items in i18n.yml.
* Obsolete ``ReVIEW::Book::Base.load_default``.
* Add ``@<imgref>`` notation.
* Add pdf, epub and cleanup tasks to sample Rakefile.
* Change all formats of documents from RDoc to Markdown.
* Add "Re:VIEW Quick Start Guide (EN)".
* Enable ``@<hd>`` to identify the target, has unique id, without ``|``.
* Add an argument lang to list related notations when highlighting.
* Add "Re:VIEW Format Guide (EN)".
* Add ``highlight`` property in config.yml as setting of highlight.

## Commands
### review-epubmaker
* Support ``toc`` in config.yml

### review-init
* Add ``--force`` option to generate files even if directory is existed.

### review-vol
* Add ``--yaml`` option.

## Builders and Makers
### markdownbuilder
* Implement ``list_header()`` and ``list_body()``.

### htmlbuilder
* Fix MathML error in ``HTMLBuilder#texequation``.

### idgxmlbuilder
*  Stop providing a index for ``@<ttb>``.

### latexbuilder
* Fix ``@<table>`` to refer the table on another chapter.
* Support syntax highlighting with listings.

### pdfmaker
* Raise errors if no LaTeX tools are installed.
* Support ``toctitle`` in config.yml.
* Remove a PDF file if already exists.
* Add parameters ``dvicommand`` and ``dvioptions`` in config.yml.
* Add parameters ``texoptions`` in config.yml.
* Load ``sty/*.fd`` and ``sty/*.cls``
* Provide hooks before/after TeX compiling.
* remove dependency on sed command
* raise errors and stop building when LaTeX command failed

### epubmaker
* Improve to support of MathML.
* Make dummy ``<li>`` item hidden in nav file.
* Introduce structured YAML tree for config.yml.
* Use ``ReVIEW::I18n`` instead of ``EPUBMaker::Resource``

## Code contributors
* akinomurasame
* gfx
* krororo
* orangain

# version 1.4.0

## In general
* Normalize ID in bib notation.
* Fix compatibility between POSTDEF file and POSTDEF section in catalog.yml.
* Add APPENDIX section into catalog.yml.
* Remove implicit settings of prefaces, appendix and postscripts.
* Refactor code and test cases.
* Add Installation, Resources and Links on README.rdoc

## Commands

### review-epubmaker
* Keep 1st stage temporary directory when debug is true.
* Support cover_linear option.

### review-catalog-converter
* Add new command which converts traditional catalog files into catalog.yml.

## Builders and Makers

### markdownbuilder
* Improve compatibility with GitHub Flavored Markdown.
* Add blank line before/after headline.
* Support tt notation.
* Support footnote notation.
* Add indepimate notation.
* Display nondisplayed image caption.

### htmlbuilder
* Provide warning message if image couldn't be found.
* Change layout file name from 'layout.erb' to 'layout.html.erb'.
* Compile caption of emlist/emlistnum/cmd notation.
* Compile title notation.

### idgxmlbuilder
* Provide warning message if image couldn't be found.

### latexbuilder
* Change layout file name from 'review.tex.erb' to 'layout.tex.erb'.
* add 'contact' for colophon in config.yml.
* add 'pbl'(publisher) for colohpon in config.yml. You can use both 'prt' and 'pbl'.

### pdfmaker
* Support locale file.
* Add colophon_order option.

### epubmaker
* Add epub:type='cover' attribute in cover file when it is EPUB3.
* Escape special HTML characters to entities in toc view.

## Code contributors
* suzuki
* vvakame
* eiel



# version 1.3.0

## In general
* Introduce a new catalog file `catalog.yml`.
* Support `@<column>{}` to refer to the column.
* Enable `@<chapref>{}` to refert to the part.
* Add safe mode as an environment variable 'REVIEW_SAFE_MODE'.
* Force *.re files to put on the same directory of the catalog files.
* Discontinue feature of setting with config.rb.
* Discontinue feature of loading lib/review/* files in the document directory.
* Introduce config `appendix_format` (arabic, roman, or alpha) to set an appendix heading style.

## Commands
* Force to use review-compile with the same version.
* Add `--version` to display the version.

### review-compile
* Add `--catalogfile` to set a catalog file.

### review-pdfmaker
* Remove tmpdir for build.
* Exit when any errors occur.
* Add `--ignore-errors` to proceed even when any errors occur.
* Generate ebb/bb files of image files in the image directory.
* Add `--[no-]debug` to override `debug` in the config.yml.

### review-init
* Generate consistent CSS filenames.

### review-epubmaker
* Rename review-empumaker to review-empumaker-legacy, then rename review-empumaker-ng to review-empumaker.
* Add `verify_target_images` and `force_include_images` configs which are related to including images in the EPUB file.

## Builders
### htmlbuilder
* Add a reverse link from the footnote to the body.
* Escape hyphens in the HTML comment tags.
* Normalize 'id' attributes.
* Enable to refer to the section titles from a layout file (`toc`).
* Enable to refer to the prev/next section from a layout file (`prev_chapter`, `next_chapter`).

### latexbuilder
* Add columns in the TOC.
* Change a image file extension as PDF in the graph notation.

## Code contributors
* kazutomi
* dmiyakawa
* zunda



# version 1.2.0

## In general

* 'ReVIEW' has been renamed to 'Re:VIEW'
* Improve the image file finder.

## Commands

### review-epubmaker-ng / review-epubmaker

* Support font embedding
* Support MathML in EPUB3
* Add prefix 'rv-' to ID
* Add pht(Photographer / 撮影者) and csl(Consultant / 監修者)
* Strip HTML element in chapter items of TOC (review-epubmaker)

### review-pdfmaker

* Add "texcommand" in config.yml to support LuaLaTeX or other latex command

### review-init

* Fix error installed by gem

## Builders

### HTMLBuilder

* Use pygments higlighting only if "pygments: true" is defined.
* Support epub:type="noteref" and epub:type="footnote" in EPUB3

### LATEXBuilder

* Add newline after //bibpaper

### MARKDOWNBuilder

* Support ``@<em>{}`` (same as ``@<i>``) and ``@<strong>{}`` (same as ``@<b>``)



# version 1.1

## in general

* add markdownbuilder
* add inaobuilder
* use bundler instead of jeweler
* add review-init command
* preserve MIME and JIS X 0201 kana during a preprocess
* fix many escape bugs (enable escape ``\[`` in ``[...]``, etc.)
* many other bugfixs

## review-compile

* add --structuredxml option(idgxml)
* add --toclevel option
* add --tabwidth option
* add --output-file option

## review-epubmaker and review-pdfmaker

* support ``foo.re`` filename in PART file
* rename tempolary dir name (bookname + "-pdf" and bookname + "-epub")

## review-epubmaker

* support epubversion and htmlversion option in YAML configuration file (EPUB3 support is experimental)
* support cover_linear option in YAML file

## review-pdfmaker

* separate tex template file from source code (see review.tex.erb)
* support layouts like HTMLbuilder

## review-compile

* add command ``//centering``
* add command ``//olnum``
* change # of arguments of ``//comment`` (1 -> 0..1)
* change # of arguments of ``//source`` (1 -> 0..1)

## htmlbuilder
* use ``<code>`` instead of ``<tt>`` in HTML5
* support ``@<bou>`` (you should use CSS3)
* support highlight with pygments
* strip ReVIEW tag in ``<title>``

## latexbuilder
* add some macro for ReVIEW(``\reviewindepimagecaption``, ``\reviewth``, ``\reviewem`` and ``\reviewstrong``).
* add argument of macro ``\reviewbibref``, ``\\reviewtableref`` and ``\reviewimageref`` to make link
* add ``\usepackage{amsmath}`` in default template.
* support ``//box``
* support ``@<ami>``
* add headline level 5 and 6 (paragraph, subparagraph)
* escape all dash
* add ``begin{alltt}..\end{alltt}`` into ``\reviewemlist``, ``\reviewlist`` and ``\reviewcmd``

