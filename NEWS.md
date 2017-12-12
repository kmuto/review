# Version 2.4.0

## New Features

* use built-in Logger class for warns and errors ([#705])
* EPUBMaker: warn of large images because of rejecting ebook stores ([#819])
* LATEXBuilder: add new inline command `@<pageref>` ([#836])
* support inline notaion `| |` and `$ $` instead of `{}` to surpress escaping `}` ([#876])

## Breaking Changes

* LATEXBuilder: use Roman numerals as part numbers ([#837])
* EPUBMaker: TOC should be after frontmatter ([#840])
* `imgmath` uses folder `images/_review_math`, not `images` directly ([#856])
* EPUBMaker: default value of titlepage is `true`, not `null` ([#862])
* EPUBMaker: `params` in template files should be `config` ([#867])
* EWBBuilder is removed because nobody maintained it ([#828])

## Bug Fixes

* fix misrecognition of HeadlineIndex ([#121])
* TOPBuilder: fix metric parameter in `//image` and `//indepimage` ([#805])
* fix refering columns in other chapters ([#817])
* use execution date when `date` in config.yml is empty ([#824])
* fix I18N messages of `listref`, `imgref`, and `tableref` in frontmatters and backmatters ([#830])
* WebMaker: fix booktitle using Hash ([#831])
* LATEXBuilder: use lmodern package to avoid to use Type3 font in Western languages ([#843])
* fix broken title using `/` in config.yml ([#852])
* PDFMaker: fix toclevel ([#846])

## Enhancements

* allow block `{ 〜 //}` in `//indepimage`. ([#802])
* warn when images are not found in `//indepimage`([#803])
* LATEXBuilder: allow caption in `//source` ([#834])

## Docs

* add that installing LaTeX environments is needed to use `rake pdf` ([#800])
* fix links in README.md ([#815])
* add sample document to test commands of Re:VIEW ([#833])
* fix comment of `titlepage` in config.yml ([#847])
* fix description of `footnotetext` ([#872])

## Others

* fix coding rules to surpress rubocop v0.50.0 ([#823])

## Contributors

* [@ryota-murakami](https://github.com/ryota-murakami)
* [@nasum](https://github.com/nasum)
* [@kokuyouwind](https://github.com/kokuyouwind)

[#121]: https://github.com/kmuto/review/issues/121
[#705]: https://github.com/kmuto/review/issues/705
[#800]: https://github.com/kmuto/review/pull/800
[#802]: https://github.com/kmuto/review/issues/802
[#803]: https://github.com/kmuto/review/issues/803
[#805]: https://github.com/kmuto/review/pull/805
[#815]: https://github.com/kmuto/review/pull/815
[#817]: https://github.com/kmuto/review/pull/817
[#819]: https://github.com/kmuto/review/issues/819
[#823]: https://github.com/kmuto/review/issues/823
[#824]: https://github.com/kmuto/review/issues/824
[#828]: https://github.com/kmuto/review/pull/828
[#830]: https://github.com/kmuto/review/pull/830
[#831]: https://github.com/kmuto/review/pull/831
[#833]: https://github.com/kmuto/review/pull/833
[#834]: https://github.com/kmuto/review/issues/834
[#836]: https://github.com/kmuto/review/issues/836
[#840]: https://github.com/kmuto/review/pull/840
[#843]: https://github.com/kmuto/review/issues/843
[#837]: https://github.com/kmuto/review/issues/837
[#846]: https://github.com/kmuto/review/issues/846
[#847]: https://github.com/kmuto/review/pull/847
[#852]: https://github.com/kmuto/review/issues/852
[#856]: https://github.com/kmuto/review/issues/856
[#862]: https://github.com/kmuto/review/pull/862
[#867]: https://github.com/kmuto/review/issues/867
[#872]: https://github.com/kmuto/review/issues/872
[#876]: https://github.com/kmuto/review/issues/876

# Version 2.3.0

## New Features

* add `//emtable`, embedded table ([#777]) ([#787])
* EPUBMaker: add new option `imgmath` ([#773]) ([#774])
* HTMLBuilder: generate images for math notations ([#774])

## Bug Fixes

* LATEXBuilder: fix chpation numbering in appendix ([#766])
* fix counting of `//imgtable` ([#782])
* fix handling of numbered/itemized list in dlist. ([#794])([#795])

## Enhancements

* add comments of backcover in doc/config.yml.sample ([#765])([#767])
* use actual part counters for heading, list, image, and table in part ([#779])
* LATEXBuilder: define the acceptable image formats for LaTeX Builder ([#785])

## Docs

* add `//embed` into NEWS.ja.md
* move `doc/NEWS.*` to top level directory ([#780])
* add how to refer images in other sections ([#770]) ([#771])
* fix description of `//table` markup ([#776])
* Use https: instead of git: ([#778])
* archive ChangeLog; use git log instead of ChangeLog ([#784]) ([#788])

## Others

* fix `.rubocop.yml` and suppress warnings

## Contributors

* [@karino2](https://github.com/karino2)
* [@imamurayusuke](https://github.com/imamurayusuke)
* [@znz](https://github.com/znz)
* [@hanachin](https://github.com/hanachin)

[#765]: https://github.com/kmuto/review/issues/765
[#766]: https://github.com/kmuto/review/issues/766
[#767]: https://github.com/kmuto/review/issues/767
[#770]: https://github.com/kmuto/review/issues/770
[#771]: https://github.com/kmuto/review/issues/771
[#773]: https://github.com/kmuto/review/issues/773
[#774]: https://github.com/kmuto/review/issues/774
[#776]: https://github.com/kmuto/review/issues/776
[#777]: https://github.com/kmuto/review/issues/777
[#778]: https://github.com/kmuto/review/issues/778
[#779]: https://github.com/kmuto/review/issues/779
[#780]: https://github.com/kmuto/review/issues/780
[#782]: https://github.com/kmuto/review/issues/782
[#784]: https://github.com/kmuto/review/issues/784
[#785]: https://github.com/kmuto/review/issues/785
[#787]: https://github.com/kmuto/review/issues/787
[#788]: https://github.com/kmuto/review/issues/788
[#795]: https://github.com/kmuto/review/issues/795


# Version 2.2.0

## New Features

* PDFMaker: support index `@<idx>`, `@<hidx>` ([#261],[#660],[#669],[#740])
* add RSTBuilder ([#733],[#738])
* add `//embed{...//}` and `@<embed>{...}` ([#730],[#751],[#757],[#758])
* HTMLBuilder, IDGXMLBuilder, LATEXBuilder: suppot `//firstlinenum` for `//listnum` and `//emlistnum` ([#685],[#688])
* review-compile: `--nolfinxml` is deprecated ([#683],[#708])
* HTMLBuilder: Enclose references (`@<img>`, `@<table>`, and `@<list>`) with `<span>`. Class names are 'imgref', 'tableref', and 'listref'. ([#696],[#697])
* HTMLBuilder: support Rouge ([#684],[#710],[#711])

## Breaking Changes

* LATEXBuilder: fix //source ([#681])
* fix escaping in inline ([#731])
    * `\}` -> `}`
    * `\\` -> `\`
    * `\x` -> `\x` (when `x` != `\` and `x` != `}`)

## Bug Fixes

* support comment for draft mode ([#360],[#717])
* i18n accepts mismatched number of arguments ([#667],[#723])
* support builder option for `//tsize` and `//latextsize` ([#716],[#719],[#720])
* remove ul_item() of html, idgxml, and markdown. ([#726],[#727])
* PDFMaker: reflect imagedir config ([#756],[#759])
* HTMLBuilder, LATEXBuilder, IDGXMLBuilder: use compile_inline in column tag
* review-init: Specify source file encoding on generating config. ([#761])
* EPUBMaker, PDFMaker: support subtitle for PDF and EPUB ([#742],[#745],[#747])
* TOPBuilder: fix `@<list>` ([#763])

## Enhancements

* LATEXBuilder: enable jumoline.sty by default
* IDGXMLBuilder, HTMLBuilder: removes errors and warnings in published document ([#753])
* image_finder.rb: support symlinked directory ([#743])
* TOPBuilder: refactor headline ([#729])
* allow free format in history of config.yml ([#693])
* HTMLBuilder: put list's id into the attribute of div.caption-code ([#724])
* without rubyzip, skip zip test ([#713],[#714])
* suppress output on checking convert command ([#712],[#718])
* TOPBuilder: support `@<bib>` and `//bibpaper` ([#763])
* TOPBuilder: support `[notoc]` and `[nodisp]` ([#763])

## Docs

* add makeindex.(ja.)md

## Others

* fix `.rubocop.yml` and suppress warnings

## Contributors

* [@kuroda](https://github.com/kuroda)
* [@olleolleolle](https://github.com/olleolleolle)
* [@shirou](https://github.com/shirou)
* [@m-shibata](https://github.com/m-shibata)
* [@kenkiku1021](https://github.com/kenkiku1021)

[#261]: https://github.com/kmuto/review/issues/261
[#360]: https://github.com/kmuto/review/issues/360
[#660]: https://github.com/kmuto/review/issues/660
[#667]: https://github.com/kmuto/review/issues/667
[#669]: https://github.com/kmuto/review/issues/669
[#681]: https://github.com/kmuto/review/issues/681
[#682]: https://github.com/kmuto/review/issues/682
[#683]: https://github.com/kmuto/review/issues/683
[#684]: https://github.com/kmuto/review/issues/684
[#685]: https://github.com/kmuto/review/issues/685
[#686]: https://github.com/kmuto/review/issues/686
[#688]: https://github.com/kmuto/review/issues/688
[#693]: https://github.com/kmuto/review/issues/693
[#696]: https://github.com/kmuto/review/issues/696
[#697]: https://github.com/kmuto/review/issues/697
[#706]: https://github.com/kmuto/review/issues/706
[#708]: https://github.com/kmuto/review/issues/708
[#710]: https://github.com/kmuto/review/issues/710
[#711]: https://github.com/kmuto/review/issues/711
[#712]: https://github.com/kmuto/review/issues/712
[#713]: https://github.com/kmuto/review/issues/713
[#714]: https://github.com/kmuto/review/issues/714
[#716]: https://github.com/kmuto/review/issues/716
[#717]: https://github.com/kmuto/review/issues/717
[#718]: https://github.com/kmuto/review/issues/718
[#719]: https://github.com/kmuto/review/issues/719
[#720]: https://github.com/kmuto/review/issues/720
[#723]: https://github.com/kmuto/review/issues/723
[#724]: https://github.com/kmuto/review/issues/724
[#726]: https://github.com/kmuto/review/issues/726
[#727]: https://github.com/kmuto/review/issues/727
[#729]: https://github.com/kmuto/review/issues/729
[#730]: https://github.com/kmuto/review/issues/730
[#731]: https://github.com/kmuto/review/issues/731
[#733]: https://github.com/kmuto/review/issues/733
[#738]: https://github.com/kmuto/review/issues/738
[#740]: https://github.com/kmuto/review/issues/740
[#742]: https://github.com/kmuto/review/issues/742
[#743]: https://github.com/kmuto/review/issues/743
[#745]: https://github.com/kmuto/review/issues/745
[#747]: https://github.com/kmuto/review/issues/747
[#751]: https://github.com/kmuto/review/issues/751
[#753]: https://github.com/kmuto/review/issues/753
[#756]: https://github.com/kmuto/review/issues/756
[#757]: https://github.com/kmuto/review/issues/757
[#758]: https://github.com/kmuto/review/issues/758
[#759]: https://github.com/kmuto/review/issues/759
[#761]: https://github.com/kmuto/review/issues/761
[#763]: https://github.com/kmuto/review/issues/763


# Version 2.1.0

## New Features

* review-init: generate Gemfile ([#650])
* HTMLBuilder: add language specified class in list ([#666])
* HTMLBuilder: set id to <div> of indepimage as same as image
* MD2INAOBuilder: support new builder MD2INAOBuilder ([#671])
* MARKDOWNBuilder, MD2INAOBuilder: support ruby ([#671])
* TEXTBuilder: support `@<hd>` ([#648])
* TOPBuilder: support `@<comment>{}` ([#625], [#627])

## Breaking Changes

## Bug Fixes

* review-validate: fix parsing blocks and comments in tables, and messages
* LATEXBuilder: fix when rights is null in config.yml ([#653])
* LATEXBuilder: escaping values from config.yml and locale.yml([#642])
* PDFMaker: support AI, EPS, and TIFF on pdfmaker correctly ([#675])
* PDFMaker: fix hooks; add @basehookdir and use it to get fullpath ([#662])
* EPUBMaker: fix missing default dc:identifier value ([#636])
* EPUBMaker: ext. of cover file should be "xhtml" in EPUB ([#618])
* WEBMaker: fix broken link ([#645])
* WEBMaker: fix when Part has no "*.re" file ([#641])
* I18n: fix `%pJ` in format_number_header ([#628])

## Enhancements

* LATEXBuilder: use pxjahyper package in pLaTeX ([#640])
* LATEXBuilder: Enhanced implementation of `layout.tex.erb` ([#617])
* LATEXBuilder: fix to use keywords in locale.yml ([#629])
* IDGXMLBuilder: add instruction to column headline for toc ([#634])
* IDGXMLBuilder: fix to avoid empty caption in //emlist ([#633])
* Rakefile: add task `preproc` ([#630])
* ReVIEW::Location: add test ([#638])

## Docs

* add customize_epub.md
* add preproc(.ja).md ([#632])
* config.yml: add `csl` in sample
* config.yml: add simplified sample ([#626])

## Others

* license of template fils are MIT license([#663])
* rubocop: suppress warnings of rubocop

## Contributors

* [@kazken3](https://github.com/kazken3)
* [@vvakame](https://github.com/vvakame)
* [@masarakki](https://github.com/masarakki)
* [@munepi](https://github.com/munepi)
* [@znz](https://github.com/znz)

[#675]: https://github.com/kmuto/review/issues/675
[#671]: https://github.com/kmuto/review/issues/671
[#666]: https://github.com/kmuto/review/issues/666
[#663]: https://github.com/kmuto/review/issues/663
[#662]: https://github.com/kmuto/review/issues/662
[#653]: https://github.com/kmuto/review/issues/653
[#650]: https://github.com/kmuto/review/issues/650
[#648]: https://github.com/kmuto/review/issues/648
[#645]: https://github.com/kmuto/review/issues/645
[#642]: https://github.com/kmuto/review/issues/642
[#641]: https://github.com/kmuto/review/issues/641
[#640]: https://github.com/kmuto/review/issues/640
[#638]: https://github.com/kmuto/review/issues/638
[#636]: https://github.com/kmuto/review/issues/636
[#634]: https://github.com/kmuto/review/issues/634
[#633]: https://github.com/kmuto/review/issues/633
[#632]: https://github.com/kmuto/review/issues/632
[#630]: https://github.com/kmuto/review/issues/630
[#629]: https://github.com/kmuto/review/issues/629
[#628]: https://github.com/kmuto/review/issues/628
[#627]: https://github.com/kmuto/review/issues/627
[#626]: https://github.com/kmuto/review/issues/626
[#625]: https://github.com/kmuto/review/issues/625
[#618]: https://github.com/kmuto/review/issues/618
[#617]: https://github.com/kmuto/review/issues/617


# Version 2.0.0

## New Features
* Load `./config.yml` if exists ([#477], [#479])
* config.yml: Add `review_version` ([#276], [#539], [#545])
   * Allow review_version to be nil, which means that I don't care about the version ([#592])
* Add experimental vertical orientation writing support ([#563])
* Support `[notoc]` and `[nodisp]` in header ([#506], [#555])
* Enable `@<column>` and `@<hd>` to refer other's column. ([#333], [#476])
* Add command `//imgtable` ([#499])
* Allow to use shortcut key of config ([#540])
    * enable to use `@config["foo"]` instead of `@config["epubmaker"]["foo"]` when using epubmaker
* Accept multiple YAML configurations using inherit parameter. ([#511], [#528])
* Add formats to i18n ([#520])
* Make `rake` run test and rubocop. ([#587])
* Add webmaker ([#498])
* LATEXBuilder: add option `image_scale2width` ([#543])
* PDFMaker: Migrate platex to uplatex ([#541])
* EPUBMaker: Support ebpaj format. ([#251], [#429])
* EPUBMaker: Add `direction` in default setting ([#508])
* EPUBMaker: Allow `pronounciation` of booktitle and author ([#507])
* review-preproc: allow monkeypatch in review-preproc ([#494])
* HTMLBuilder: Disable hyperlink with `@<href>` with epubmaker/externallink: false in config.yml ([#509], [#544])
* EPUBMaker: Add custom prefix and `<meta>` element in OPF ([#513])
* PDFMaker: support `history` in config ([#566])

## Breaking Changes
* Update `epubversion` and `htmlversion` ([#542])
* Delete backward compatibility of 'param'. ([#594])
* config.yml: 'pygments:' is obsoleted. ([#604])
* Remove backward compatibility ([#560])
    * layout.erb -> layout.html.erb
    * locale.yaml -> locale.yml
    * PageMetric.a5 -> PageMetric::A5
    * raise error when using locale.yaml and layout.erb
    * `prt` is printer(`印刷所`), not publisher(`発行所`).  `発行所` is `pbl`.  ([#562, #593])
* Obsolete `appendix_format` ([#609])
* Remove obsolete inaobuilder. (upstream changed their mind to use modified Markdown) ([#573])
* Remove obsolete legacy epubmaker
* review-compile: Remove `-a/--all` option ([#481])

## Bug Fixes
* Escape html correctly. ([#589], [#591])
* review-epubmaker: fix error of not copying all images. ([#224])
* Fix several bugs around `[nonum]`. ([#301], [#436], [#506], [#550], [#554], [#555])
* IDGXMLBuilder: fix wrong calcuration between pt and mm for table cell width on IDGXML. ([#558])
* HTMLBuilder: use `class` instead of `width` for `//image[scale=XXX]`  ([#482], [#372]). It fixes on epubcheck test.

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
* Add `name_of` and `names_of` method into Configure class to take 'name' attribute value. ([#534])
* EPUBMaker: reflected colophon_order. ([#460])
* TOCPrinter: remove IDGTOCPrinter. ([#486])
* Add new methods: Book#catalog=(catalog) and Catalog.new(obj) ([93691d0e2601eeb5715714b4fb92840bb3b3ff8b])
* Chapter and Part: do not use lazy loading. ([#491])

## Docs
* README: rdoc -> md ([#610])
* Update format.md, quickstart.md
* Add note about writing vertical document and PDFMaker
* Fix document in EN ([#588])

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

