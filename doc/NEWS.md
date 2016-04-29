# Version 2.0.0

## New Features
* Load `./config.yml` if exists ([#477], [#479])
* Add webmaker ([#498])
* config.yml: Add `review_version` ([#276], [#539], [#545])
   * Allow review_version to be nil, which means that I don't care about the version ([#592])
* Add experimental vertical orientation writing support ([#563])
* Support `[notoc]` and `[nodisp]` in header ([#506], [#555])
* LATEXBuilder: add option `image_scale2width` ([#543])
* Support ebpaj format. ([#251], [#429])
* Enable `@<column>` and `@<hd>` to refer other's column. ([#333], [#476])
* Migrate platex to uplatex ([#541])
* Add `direction` in default setting ([#508])
* Allow `pronounciation` of booktitle ([#507])
* review-preproc: allow monkeypatch in review-preproc ([#494])
* Add command `//imgtable` ([#499])
* Disable hyperlink with `@<href>` with epubmaker/externallink: false in config.yml ([#509], [#544])
* Allow to use shortcut key of config ([#540])
    * enable to use `@config["foo"]` instead of `@config["epubmaker"]["foo"]` when using epubmaker
* Update `epubversion` and `htmlversion` ([#542])
* Accept multiple YAML configurations using inherit parameter. ([#511], [#528])
* Add custom prefix and `<meta>` element in OPF ([#513])
* Add formats to i18n ([#520])
* PDFMaker: support `history` in config ([#566])
* Make `rake` run test and rubocop. ([#587])

## Breaking Changes
* Delete backward compatibility of 'prt'.  ([#593])
* Delete backward compatibility of 'param'. ([#594])
* config:yml: 'pygments:' is obsoleted. ([#604])
* Remove obsolete inaobuilder. (upstream changed their mind to use modified Markdown) ([#573])
* Remove backward compatibility ([#560])
    * layout.erb -> layout.html.erb
    * locale.yaml -> locale.yml
    * PageMetric.a5 -> PageMetric::A5
    * raise error when using locale.yaml and layout.erb
    * `prt` is printer(`印刷所`), not publisher(`発行所`)  ([#562])
    * `発行所` is `pbl`.
* Obsolete `appendix_format` ([#609])
* review-compile: Remove `-a/--all` option ([#481])
* Remove obsolete legacy epubmaker

## Bug Fixes
* Escape html correctly. ([#589], [#591])
* review-epubmaker: fix error of not copying all images. ([#224])
* Fix several bugs around `[nonum]`. ([#301], [#436], [#506], [#550], [#554], [#555])
* IDGXMLBuilder: fix wrong calcuration between pt and mm for table cell width on IDGXML. ([#558])

## Refactorings
* Support named parameters in EPUBmaker/PDFmaker ([#534])
* Add `ReVIEW::YAMLLoader` ([#518])
* Remove global variables. ([#240])
* Set warning to false in test. ([#597])
* Avoid warnings (avoid circular require, unused variable, redefining methods, too many args) ([#599], [#601])
* MakerHelper: class -> module ([#582])
* review-init: generate config.yml from doc/config.yml.sample. ([#580])
* Unify template engine ReVIEW::Template  ([#576])
  * HTMLBuilder: remove HTMLLayout
  * LATEXBuilder: use instance variable in templates ([#598])
  * LATEXBuilder: move lib/review/layout.tex.erb to templates/latex/ ([#572])
* Update config.yml.sample ([#579])
* Remove code for 1.8 and 1.9.3 in test (for Travis) ([#577])
* Fix LaTeX templates ([#575])
* Use read BOM|utf-8 flag for opening files, instead of string replacing ([#574])
* review-preproc: set default_external encoding UTF-8. ([#486])
* Fix pdf and epub build_path on debug ([#564], [#556])
* Refactor EPUBMaker. ([#533])
* Use SecureRandom.uuid instead of ruby-uuid ([#497])
* epubmaker, pdfmaker: Use ReVIEW::Converter instead of system() ([#493])
* Remove zip command and use PureRuby Zip library ([#487])
* review-index: refine TOCParser and TOCPrinter ([#486])
* Remove deprecated parameters, change default value of some parameters. ([#547])
* sample config.yml should be config.yml.* ([#538])
* Add `Hash#deep_merge` ([#523])
* LATEXBuilder: use `\reviewunderline` instead of `\Underline`  ([#408])
* HTMLBuilder: use `class` instead of `width` for `//image[scale=XXX]`  ([#482], [#372])
* Add `name_of` and `names_of` method into Configure class to take 'name' attribute value. ([#534])
* EPUBMaker: reflected colophon_order. ([#460])
* TOCParser: ([67014a65411e3a3e5e2c57c57e01bee1ad18efc6])
* TOCPrinter: remove IDGTOCPrinter. ([#486])
* Add new methods: Book#catalog=(catalog) and Catalog.new(obj) ([93691d0e2601eeb5715714b4fb92840bb3b3ff8b])
* Chapter and Part: do not use lazy loading. ([#491])
* change prefix -> opf_prefix. ([2bbedaa2be03692cba5c4985b561ee2553bf1521])

## Docs
* README: rdoc -> md ([#610])
* Fix document in EN ([#588])
* Add note about writing vertical document
* Update quickstart.ja

## Code contributors
* [@arikui1911](https://github.com/arikui1911)

[#224]: https://github.com/kmuto/review/issues/224
[#240]: https://github.com/kmuto/review/issues/240
[#251]: https://github.com/kmuto/review/issues/251
[#276]: https://github.com/kmuto/review/issues/276
[#301]: https://github.com/kmuto/review/issues/301
[#333]: https://github.com/kmuto/review/issues/333
[#372]: https://github.com/kmuto/review/issues/372
[#408]: https://github.com/kmuto/review/issues/408
[#429]: https://github.com/kmuto/review/issues/429
[#436]: https://github.com/kmuto/review/issues/436
[#460]: https://github.com/kmuto/review/issues/460
[#476]: https://github.com/kmuto/review/issues/476
[#477]: https://github.com/kmuto/review/issues/477
[#479]: https://github.com/kmuto/review/issues/479
[#481]: https://github.com/kmuto/review/issues/481
[#482]: https://github.com/kmuto/review/issues/482
[#486]: https://github.com/kmuto/review/issues/486
[#487]: https://github.com/kmuto/review/issues/487
[#491]: https://github.com/kmuto/review/issues/491
[#493]: https://github.com/kmuto/review/issues/493
[#494]: https://github.com/kmuto/review/issues/494
[#497]: https://github.com/kmuto/review/issues/497
[#498]: https://github.com/kmuto/review/issues/498
[#499]: https://github.com/kmuto/review/issues/499
[#506]: https://github.com/kmuto/review/issues/506
[#507]: https://github.com/kmuto/review/issues/507
[#508]: https://github.com/kmuto/review/issues/508
[#509]: https://github.com/kmuto/review/issues/509
[#511]: https://github.com/kmuto/review/issues/511
[#513]: https://github.com/kmuto/review/issues/513
[#518]: https://github.com/kmuto/review/issues/518
[#520]: https://github.com/kmuto/review/issues/520
[#523]: https://github.com/kmuto/review/issues/523
[#528]: https://github.com/kmuto/review/issues/528
[#533]: https://github.com/kmuto/review/issues/533
[#534]: https://github.com/kmuto/review/issues/534
[#538]: https://github.com/kmuto/review/issues/538
[#539]: https://github.com/kmuto/review/issues/539
[#540]: https://github.com/kmuto/review/issues/540
[#541]: https://github.com/kmuto/review/issues/541
[#542]: https://github.com/kmuto/review/issues/542
[#543]: https://github.com/kmuto/review/issues/543
[#544]: https://github.com/kmuto/review/issues/544
[#545]: https://github.com/kmuto/review/issues/545
[#547]: https://github.com/kmuto/review/issues/547
[#550]: https://github.com/kmuto/review/issues/550
[#554]: https://github.com/kmuto/review/issues/554
[#555]: https://github.com/kmuto/review/issues/555
[#556]: https://github.com/kmuto/review/issues/556
[#557]: https://github.com/kmuto/review/issues/557
[#558]: https://github.com/kmuto/review/issues/558
[#560]: https://github.com/kmuto/review/issues/560
[#562]: https://github.com/kmuto/review/issues/562
[#563]: https://github.com/kmuto/review/issues/563
[#564]: https://github.com/kmuto/review/issues/564
[#566]: https://github.com/kmuto/review/issues/566
[#572]: https://github.com/kmuto/review/issues/572
[#573]: https://github.com/kmuto/review/issues/573
[#574]: https://github.com/kmuto/review/issues/574
[#575]: https://github.com/kmuto/review/issues/575
[#576]: https://github.com/kmuto/review/issues/576
[#577]: https://github.com/kmuto/review/issues/577
[#579]: https://github.com/kmuto/review/issues/579
[#580]: https://github.com/kmuto/review/issues/580
[#582]: https://github.com/kmuto/review/issues/582
[#587]: https://github.com/kmuto/review/issues/587
[#588]: https://github.com/kmuto/review/issues/588
[#589]: https://github.com/kmuto/review/issues/589
[#591]: https://github.com/kmuto/review/issues/591
[#592]: https://github.com/kmuto/review/issues/592
[#593]: https://github.com/kmuto/review/issues/593
[#594]: https://github.com/kmuto/review/issues/594
[#597]: https://github.com/kmuto/review/issues/597
[#598]: https://github.com/kmuto/review/issues/598
[#599]: https://github.com/kmuto/review/issues/599
[#601]: https://github.com/kmuto/review/issues/601
[#604]: https://github.com/kmuto/review/issues/604
[#609]: https://github.com/kmuto/review/issues/609
[#610]: https://github.com/kmuto/review/issues/610
[93691d0e2601eeb5715714b4fb92840bb3b3ff8b]: https://github.com/kmuto/review/commit/93691d0e2601eeb5715714b4fb92840bb3b3ff8b
[2bbedaa2be03692cba5c4985b561ee2553bf1521]: https://github.com/kmuto/review/commit/2bbedaa2be03692cba5c4985b561ee2553bf1521
[67014a65411e3a3e5e2c57c57e01bee1ad18efc6]: https://github.com/kmuto/review/commit/67014a65411e3a3e5e2c57c57e01bee1ad18efc6

# Version 1.7.2

## Bug Fix
* Fix latexbuilder to show caption in `//list` without highliting ([#465])
* Fix markdownbuilder to use definition list ([#473])

# Version 1.7.1

## Bug Fix
* Fix latexbuilder to display caption twice in `//listnum` ([#465])
* Fix review-init to generate non-valid EPUB3 file with epubcheck 4.0.1 ([#456])

# Version 1.7.0

## In general
* Set up Rubocop settings and refactor code with the settings
* Change the internal encoding to UTF-8 altogether ([#399])
* Add a Dockerfile

## Bug Fix
* Fix htmlbuilder to display line numbers with listnum/emlistnum under a syntax highlighting environment ([#449])

## Builders and Makers

### epubmaker
* Support ``direction`` parameter to set binding direction ([#435])

## Code contributors
* [@snoozer05](https://github.com/snoozer05)

[#399]: https://github.com/kmuto/review/pull/399
[#435]: https://github.com/kmuto/review/pull/435
[#449]: https://github.com/kmuto/review/issues/449

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

