# Version 5.7.0
## Bug Fixes
* Fixed error when omitting a bind address of `review-init -w` on Windows ([#1824])
* EPUBMaker: escape `<`, `>`, and `&` when converting to MathJax to avoid HTML errors ([#1876], [#1877])

## Breaking Changes
* Ruby 2.6 or earlier was excluded from the operation verification ([#1871])
* EPUMaker: included a link to the cover in the table of contents according to EPUB validation rules ([#1874])

## Others
* Ruby 3.2 is now included in the testing target ([#1871])
* refactor code with RuboCop 1.45.1 ([#1878])

[#1824]: https://github.com/kmuto/review/issues/1824
[#1871]: https://github.com/kmuto/review/pull/1871
[#1872]: https://github.com/kmuto/review/issues/1872
[#1874]: https://github.com/kmuto/review/issues/1874
[#1876]: https://github.com/kmuto/review/pull/1876
[#1877]: https://github.com/kmuto/review/pull/1877
[#1878]: https://github.com/kmuto/review/pull/1878

# Version 5.6.0
## New Features
* IDGXMLBuilder: support `imgmath` math_format in `//texequation` and `@<m>` ([#1829])
* LATEXBuilder: use `reviewicon` macro instead of `reviewincludegraphics` in `@<icon>` ([#1838])
* trim spaces before/after characters in ruby text ([#1839])

## Breaking Changes
* LATEXBuilder: use `MEMO`, `NOTICE`, `CAUTION` or other headers instead of `■メモ`. If you want to use older headers, add `■メモ` in `locale.yml`. ([#1856])

## Others
* update documents `format.md` and `format.ja.md` ([#1860])

[#1829]: https://github.com/kmuto/review/pull/1829
[#1838]: https://github.com/kmuto/review/pull/1838
[#1839]: https://github.com/kmuto/review/pull/1839
[#1856]: https://github.com/kmuto/review/pull/1856
[#1860]: https://github.com/kmuto/review/pull/1860

# Version 5.5.0
## New Features
* introduced `@<secref>`, `@<sec>`, and `@<sectitle>` as inline op to refer sections ([#1809])

## Bug Fixes
* fixed test error ([#1804])
* fixed an error of review-update ([#1807])

## Others
* added rexml to gemspec ([#1808])

[#1804]: https://github.com/kmuto/review/pull/1804
[#1807]: https://github.com/kmuto/review/pull/1807
[#1808]: https://github.com/kmuto/review/pull/1808
[#1809]: https://github.com/kmuto/review/issues/1809

# Version 5.4.0
## New Features
* [GitHub Discussions](https://github.com/kmuto/review/discussions) has been opened to answer questions about Re:VIEW

## Breaking Changes
* EPUBMaker: `manifest/item` in the opf file is now sorted by the dictional order of ID strings ([#1763])
* TextMaker: the separator line now put between the heading rows and the normal rows of the table. To revert this behavior to old version, set `textmaker/th_bold` parameter to true ([#1789])
* TextMaker: the output result of the `//indepimage` op has been adjusted to `//image` ([#1790])
* TextMaker: the output result of the `//imgtable` op has been adjusted to `//image` and `//table` ([#1791])
* `//source` op is now also not escaped when highlighting is enabled ([#1788])

## Bug Fixes
* fixed YAML error in Ruby 3.1 and kept backward compatibility ([#1767], [#1775])
* EPUBMaker: removed `epub:type=cover` from titlepage and colophon ([#1776])
* removed invalid urnid sample ([#1779])
* when there is a syntax error in config.yml, exit with proper error message instead of an exception ([#1797])
* IDGXMLMaker: fixed an error to compile prefaces or postfaces when secttags is enabled ([#1800])

## Enhancements
* EPUBMaker, WebMaker: use `layout.html.erb` or `layout-web.html.erb` as the base template for cover, titlepage, colophon, and part, just like regular chapters ([#1780])
* EPUBMaker, WebMaker: cover, titlepage, colophon, and part can now be overwritten with `_cover.html.erb`, `_titlepage.html.erb`, `_colophon.html.erb`, `_colophon_history.html.erb`, and `_part_body.html.erb` ([#1777])

## Docs
* mentioned GitHub Discussions in README.md ([#1772])

## Others
* refactor code with RuboCop 1.25.1 ([#1773], [#1782], [#1783], [#1784], [#1792])

[#1763]: https://github.com/kmuto/review/pull/1763
[#1767]: https://github.com/kmuto/review/pull/1767
[#1772]: https://github.com/kmuto/review/pull/1772
[#1773]: https://github.com/kmuto/review/pull/1773
[#1775]: https://github.com/kmuto/review/pull/1775
[#1776]: https://github.com/kmuto/review/pull/1776
[#1777]: https://github.com/kmuto/review/issues/1777
[#1779]: https://github.com/kmuto/review/pull/1779
[#1780]: https://github.com/kmuto/review/pull/1780
[#1782]: https://github.com/kmuto/review/pull/1782
[#1783]: https://github.com/kmuto/review/pull/1783
[#1784]: https://github.com/kmuto/review/pull/1784
[#1788]: https://github.com/kmuto/review/pull/1788
[#1789]: https://github.com/kmuto/review/issues/1789
[#1790]: https://github.com/kmuto/review/issues/1790
[#1791]: https://github.com/kmuto/review/issues/1791
[#1792]: https://github.com/kmuto/review/pull/1792
[#1797]: https://github.com/kmuto/review/issues/1797
[#1800]: https://github.com/kmuto/review/pull/1800

# Version 5.3.0
## New Features
* add the future of endnote. `//endnote` specifies the content of the endnote, `@<endnote>` specifies the reference to the endnote, and `//printendnotes` places endnotes ([#1724])

## Bug Fixes
* fixed an error in new jlreq that caused it to become independent of ifthen package ([#1718])
* fixed an issue with hidden folio being set to all 1 when using review-jsbook with TeXLive 2020 or later ([#1720])
* fixed an error that occurred when a non-existent file was specified in the coverimage parameter ([#1726], [#1729])
* it now warns when a non-existent file is specified in the titlefile, creditfile, and profile parameters ([#1730])
* fixed `@<tcy>` op error in review-jlreq. this op will be expanded into `\reviewtcy` macro ([#1733])
* fixed exception errors in review-vol and review-index ([#1740])
* fixed forgetting to copy `__IMGMATH_BODY__.tex` when math compiling error occurs ([#1747])
* fixed the problem that the position of `//beginchild` and `//endchild` is not displayed when an error occurs ([#1742])
* fixed a build error when using `//graph` op ([#1744])
* fixed undefined variable in epubmaker.rb ([#1755])
* fixed execution error in review-catalog-converter ([#1753])

## Enhancements
* warnings are now given when footnotes (`//footnote`) and endnotes (`//endnote`) are defined but not referenced (`@<fn>`, `@<endnote>`) ([#1725])
* `\includefullpagegraphics` macro that pastes an image over the entire page now supports vertical writing ([#1734])
* try to find plantuml.jar from the working folder, `/usr/share/plantuml`, or `/usr/share/java` ([#1760])

## Docs
* format.ja.md, format.md: fixed a mistake in the command line for creating SVG formulas ([#1748])

## Others
* added tests for Ruby 2.7 for Windows ([#1743])
* refactor code with Rubocop 1.22.1 ([#1759])

## Contributors
* [@munepi](https://github.com/munepi)
* [@huideyeren](https://github.com/huideyeren)

[#1718]: https://github.com/kmuto/review/issues/1718
[#1720]: https://github.com/kmuto/review/issues/1720
[#1724]: https://github.com/kmuto/review/issues/1724
[#1725]: https://github.com/kmuto/review/issues/1725
[#1726]: https://github.com/kmuto/review/issues/1726
[#1729]: https://github.com/kmuto/review/pull/1729
[#1730]: https://github.com/kmuto/review/pull/1730
[#1733]: https://github.com/kmuto/review/issues/1733
[#1734]: https://github.com/kmuto/review/issues/1734
[#1740]: https://github.com/kmuto/review/pull/1740
[#1742]: https://github.com/kmuto/review/pull/1742
[#1743]: https://github.com/kmuto/review/pull/1743
[#1744]: https://github.com/kmuto/review/issues/1744
[#1747]: https://github.com/kmuto/review/pull/1747
[#1748]: https://github.com/kmuto/review/pull/1748
[#1753]: https://github.com/kmuto/review/issues/1753
[#1755]: https://github.com/kmuto/review/issues/1755
[#1759]: https://github.com/kmuto/review/pull/1759
[#1760]: https://github.com/kmuto/review/pull/1760

# Version 5.2.0
## New Features
* EPUBMaker: added `<section>` based on heading level for CSS formatting, when the `epubmaker/use_section` parameter is set to `true` ([#1685])

## Bug Fixes
* PDFMaker: fixed a problem that caused a warning in templates for Ruby 2.6 and above ([#1683])
* EPUBMaker: fixed an issue that caused copied files to be empty in Docker environments ([#1686])
* added CSS style for correct displaying horizontal characters in vertical typesetting ([#1688])
* PDFMaker: fixed the pxjahyper option conflict error on latest TeXLive ([#1690])
* PDFMaker: fixed compile error when image is not found ([#1706])

## Enhancements
* improve around warn and error handling ([#1674])
* PDFMaker: introduced `pdfmaker/use_symlink` parameter to speed up the process by using symbolic links instead of actual copies. This may not work on some operating systems such as Windows ([#1696])
* PDFMaker: don't insert empty page after frontmatter when using review-jlreq with `serial_pagination=true, openany` ([#1711])

## Others
* fixed related to GitHub Actions ([#1684], [#1691])
* review-preproc: refactored ([#1697])
* refactored nested lists handling ([#1698])
* refactor code with Rubocop 1.12 ([#1689], [#1692], [#1699], [#1700])
* The `builder_init_file` method of each builder now executes `super` first to use base builder's `builder_init_file` ([#1702])
* PDFMaker: Stopped implicitly including FileUtils library ([#1704])

## Contributors
* [@odaki](https://github.com/odaki)
* [@imamurayusuke](https://github.com/imamurayusuke)

[#1674]: https://github.com/kmuto/review/issues/1674
[#1683]: https://github.com/kmuto/review/pulls/1683
[#1684]: https://github.com/kmuto/review/pulls/1684
[#1685]: https://github.com/kmuto/review/pulls/1685
[#1686]: https://github.com/kmuto/review/issues/1686
[#1688]: https://github.com/kmuto/review/pulls/1688
[#1689]: https://github.com/kmuto/review/pulls/1689
[#1690]: https://github.com/kmuto/review/pulls/1690
[#1691]: https://github.com/kmuto/review/pulls/1691
[#1692]: https://github.com/kmuto/review/pulls/1692
[#1696]: https://github.com/kmuto/review/issues/1696
[#1697]: https://github.com/kmuto/review/pulls/1697
[#1698]: https://github.com/kmuto/review/pulls/1698
[#1699]: https://github.com/kmuto/review/pulls/1699
[#1700]: https://github.com/kmuto/review/pulls/1700
[#1702]: https://github.com/kmuto/review/pulls/1702
[#1704]: https://github.com/kmuto/review/pulls/1704
[#1706]: https://github.com/kmuto/review/issues/1706
[#1711]: https://github.com/kmuto/review/issues/1711

# Version 5.1.1
## Bug Fixes
* Fix the runtime error of `review-preproc` ([#1679])

[#1679]: https://github.com/kmuto/review/issues/1679

# Version 5.1.0
## New Features
* added Rake rule to call [Vivliostyle-CLI](https://github.com/vivliostyle/vivliostyle-cli), CSS typesetting formatter. Create a PDF with `rake vivliostyle:build` or `rake vivliostyle`, and open a preview with `rake vivliostyle:preview` ([#1663])
* PDFMaker: introduced `boxsetting` parameter to choose and customize the decorations for column, note, memo, tip, info, warning, important, caution and notice ([#1637])
* added inline op, `@<ins>` (indicates an insertion) and `@<del>` (indicates a deletion) ([#1630])
* EPUBMaker, WebMaker: MathJax is now supported. Added `math_format` parameter to choose the mathematical expression method ([#1587], [#1614])

## Breaking Changes
* EPUBMaker: changed the default value of the `urnid` parameter from `urn:uid` to `urn:uuid` ([#1658])
* PDFMaker: footnotes are no longer broken up by a page ([#1607])

## Bug Fixes
* fixed WebMaker, review-vol and review-index errors when `contentdir` is defined ([#1633])
* WebMaker: fixed `images/html` foder not being found ([#1623])
* PDFMaker: fixed chapterlink in term list ([#1619])
* PDFMaker: fixed errors when index contains `{`, `}`, or `|` ([#1611])
* review-vol: valid error messages will be displayed when invalid headings are found ([#1604])
* PDFMaker: `after_makeindex` hook to be executed after `mendex` execution, not after LaTeX compilation ([#1605])
* PDFMaker: if the caption of `//image` is empty, the figure number will be printed instead of an internal error ([#1666])
* fixed review-vol and review-index errors when a file is invalid ([#1671])
* EPUBMaker: fixed an error when static file is missing ([#1670])

## Enhancements
* Maker commands now display with nice colors and icons for their progress status when tty-logger gem is installed ([#1660])
* PDFMaker: added `\RequirePackage{plautopatch}` definition to class files ([#1644])
* MARKDOWNBuilder: supported `@<hd>` ([#1629])
* Re:VIEW now reports an error when a document file contains invalid escape sequence characters ([#1596], [#1602])
* an error is raised when there are more than 6 `=` in a heading ([#1591])

## Docs
* documented the name of the image folder referenced by Makers ([#1626])

## Others
* EPUBMaker: moved EPUB library from `lib/epubmaker` to `lib/review/epubmaker` and refactored it ([#1575], [#1617], [#1635], [#1640], [#1641], [#1650], [#1653], [#1655])
* EPUBMaker: added tests ([#1656])
* PDFMaker: refactored some ([#1664])
* introduced `ReVIEW::ImgMath` class to handle mathematic images ([#1642], [#1649], [#1659], [#1662])
* IDGXMLMaker: refactored some ([#1654])
* MakerHelper: refactored some ([#1652])
* introduced `ReVIEW::Template.generate` class to handle the templates ([#1648])
* added a test of TeX compilation to GitHub Actions ([#1643])
* refactored codes according to Rubocop 1.10 ([#1593], [#1598], [#1613], [#1636], [#1647], [#1669])
* fixed duplicate IDs of syntax-book sample ([#1646])
* refactored the way to reference relative pathes ([#1639])
* refactored `ReVIEW::LineInput` class ([#1638])
* update Copyright to 2021 ([#1632])
* added Ruby 3.0 to the test platform ([#1622])
* suppressed tests for Pygments ([#1610], [#1618])
* WebTocPrinter: fixed an error of test ([#1606])
* improved to make it easier to specify the target of the test ([#1594])

[#1671]: https://github.com/kmuto/review/issues/1671
[#1670]: https://github.com/kmuto/review/pull/1670
[#1669]: https://github.com/kmuto/review/pull/1669
[#1666]: https://github.com/kmuto/review/issues/1666
[#1664]: https://github.com/kmuto/review/pull/1664
[#1663]: https://github.com/kmuto/review/pull/1663
[#1662]: https://github.com/kmuto/review/issues/1662
[#1660]: https://github.com/kmuto/review/issues/1660
[#1659]: https://github.com/kmuto/review/pull/1659
[#1658]: https://github.com/kmuto/review/pull/1658
[#1656]: https://github.com/kmuto/review/pull/1656
[#1655]: https://github.com/kmuto/review/pull/1655
[#1654]: https://github.com/kmuto/review/pull/1654
[#1653]: https://github.com/kmuto/review/pull/1653
[#1652]: https://github.com/kmuto/review/pull/1652
[#1650]: https://github.com/kmuto/review/pull/1650
[#1649]: https://github.com/kmuto/review/pull/1649
[#1648]: https://github.com/kmuto/review/pull/1648
[#1647]: https://github.com/kmuto/review/pull/1647
[#1646]: https://github.com/kmuto/review/pull/1646
[#1644]: https://github.com/kmuto/review/issues/1644
[#1643]: https://github.com/kmuto/review/pull/1643
[#1642]: https://github.com/kmuto/review/pull/1642
[#1641]: https://github.com/kmuto/review/pull/1641
[#1640]: https://github.com/kmuto/review/pull/1640
[#1639]: https://github.com/kmuto/review/pull/1639
[#1638]: https://github.com/kmuto/review/pull/1638
[#1637]: https://github.com/kmuto/review/pull/1637
[#1636]: https://github.com/kmuto/review/pull/1636
[#1635]: https://github.com/kmuto/review/pull/1635
[#1633]: https://github.com/kmuto/review/issues/1633
[#1632]: https://github.com/kmuto/review/issues/1632
[#1630]: https://github.com/kmuto/review/issues/1630
[#1629]: https://github.com/kmuto/review/pull/1629
[#1626]: https://github.com/kmuto/review/pull/1626
[#1623]: https://github.com/kmuto/review/issues/1623
[#1622]: https://github.com/kmuto/review/pull/1622
[#1619]: https://github.com/kmuto/review/issues/1619
[#1618]: https://github.com/kmuto/review/pull/1618
[#1617]: https://github.com/kmuto/review/pull/1617
[#1614]: https://github.com/kmuto/review/pull/1614
[#1613]: https://github.com/kmuto/review/pull/1613
[#1611]: https://github.com/kmuto/review/issues/1611
[#1610]: https://github.com/kmuto/review/pull/1610
[#1607]: https://github.com/kmuto/review/issues/1607
[#1606]: https://github.com/kmuto/review/issues/1606
[#1605]: https://github.com/kmuto/review/issues/1605
[#1604]: https://github.com/kmuto/review/issues/1604
[#1602]: https://github.com/kmuto/review/pull/1602
[#1598]: https://github.com/kmuto/review/pull/1598
[#1596]: https://github.com/kmuto/review/issues/1596
[#1594]: https://github.com/kmuto/review/pull/1594
[#1593]: https://github.com/kmuto/review/pull/1593
[#1591]: https://github.com/kmuto/review/issues/1591
[#1587]: https://github.com/kmuto/review/issues/1587
[#1575]: https://github.com/kmuto/review/issues/1575

# Version 5.0.0
## New Features
* added `cover_fit_page` option to review-jsbook / review-jlreq classes. When `cover_fit_page=true` is specified in the `texdocumentclass` parameter, the cover image is scaled to paper size. Note: it is recommended that the images should be created at actual size ([#1534])
* allow minicolumn nesting. Now you can put a block instruction such as `//image` or itemized list in minicolumn (`//note`, `//memo`, `//tip`, `//info`, `//warning`, `//important`, `//caution`, `//notice`) ([#1558], [#1562])
* added single commands `//beginchild` and `//endchild` for nesting itemized/enumerate/description list. **EXPERIMENTAL FEATURE** ([#1497])

## Breaking Changes
* In review-jlreq.cls, hiddenfolio is now implemented by jlreqtrimmarkssetup. It is slightly different from the previous version in position and display ([#1397])
* The default value of the `chapterlink` parameter is now true. Most links (chapter, section, image, table, list, equation, bibliography) in Web and EPUB are now hyperlinked. In TeX PDF, some links (chapter, section, biliography) are hyperlinked only when `media=ebook` ([#1529])

## Bug Fixes
* PDFMaker: fixed a problem with multiple same-named image files with different extensions that would cause them to be misaligned ([#1483])
* PDFMaker: fixed a problem that cuased an error when the author name (`aut`) was empty ([#1517])
* PDFMaker: fixed a problem that caused an error if `//indepimage`'s image file didn't exist and ID contained characters to be TeX-escaped ([#1527])
* PDFMaker: fixed a problem with characters to be TeX-escaped in the `bookttilename` and `aut` parameters causing incorrect PDF metainformation ([#1533])
* WebMaker: fixed to avoid nil in HTML template ([#1545])
* PDFMaker: fixed a problem when hiding chapter numbers ([#1559])
* MarkdownBuilder: paragraphs in minicolumn should be separated with a blank line instead of a newline ([#1572])

## Enhancements
* fix warning message to output more detailed information of item ([#1523])
* PDFMaker: make `@<hd>` op a hyperlink (when `media=ebook`) ([#1530])
* use `cgi/escape` first and `cgi/util` as fallback. remove orignal implementation in `ReVIEW::HTMLUtils.escape()` ([#1536])
* suppress warning with same `@<icon>` ([#1541])
* fix an error handling when a badly encoded file is received ([#1544])
* introduce IndexBuilder. IndexBuilder first scans the entire project files and provides indexes for each builder ([#1384], [#1552])
* IDs and labels containing below characters or space characters are now warned ([#1393], [#1574])
```
#%\{}[]~/$'"|*?&<>`
```

## Docs
* fix a typo in format.ja.md and format.md ([#1528])
* fix incorrect example in makeindex.ja.md ([#1584])

## Others
* refactor code with Rubocop 0.92.0 ([#1511], [#1569], [#1573])
* rename `@strategy` to `@builder` in `Re:VIEW::Compiler` ([#1520])
* refactor code with Rubocop-performance 1.7.1 ([#1521])
* update Gemfile in syntax-book ([#1522])
* calling GhostScript in ImageMagick has been deprecated, so the test has been removed ([#1526])
* unnecessary stderr output on some test units has been suppressed ([#1538])
* add `BookUnit` class instead of `Compilable` module, the super class of `Chapter` and `Part` ([#1543])
* `ReVIEW::Book.load` is deprecated, use `ReVIEW::Book::Base.load` or `ReVIEW::Book::Base.new` add new option `:config` for `ReVIEW::Book::Base.load` ([#1548], [#1563])
* added `ReVIEW::Configure.create` ([#1549])
* WebMaker: removed unused `clean_mathdir` ([#1550])
* add `Base#parse_catalog_file()` and use it in `ReVIEW::Book::Base.new()`. `Base#catalog` is just getter now  ([#1551])
* use `File.write` when it can be used ([#1560])
* remove `Builder#builder_init()` ([#1564])

## Contributors
* [@snoozer05](https://github.com/snoozer05)

[#1384]: https://github.com/kmuto/review/pull/1384
[#1393]: https://github.com/kmuto/review/issues/1393
[#1397]: https://github.com/kmuto/review/issues/1397
[#1483]: https://github.com/kmuto/review/issues/1483
[#1497]: https://github.com/kmuto/review/pull/1497
[#1511]: https://github.com/kmuto/review/pull/1511
[#1517]: https://github.com/kmuto/review/issues/1517
[#1520]: https://github.com/kmuto/review/pull/1520
[#1521]: https://github.com/kmuto/review/pull/1521
[#1522]: https://github.com/kmuto/review/pull/1522
[#1523]: https://github.com/kmuto/review/pull/1523
[#1526]: https://github.com/kmuto/review/pull/1526
[#1527]: https://github.com/kmuto/review/pull/1527
[#1528]: https://github.com/kmuto/review/pull/1528
[#1529]: https://github.com/kmuto/review/issues/1529
[#1530]: https://github.com/kmuto/review/issues/1530
[#1533]: https://github.com/kmuto/review/issues/1533
[#1534]: https://github.com/kmuto/review/issues/1534
[#1536]: https://github.com/kmuto/review/pull/1536
[#1538]: https://github.com/kmuto/review/pull/1538
[#1541]: https://github.com/kmuto/review/pull/1541
[#1543]: https://github.com/kmuto/review/pull/1543
[#1544]: https://github.com/kmuto/review/issues/1544
[#1545]: https://github.com/kmuto/review/issues/1545
[#1548]: https://github.com/kmuto/review/pull/1548
[#1549]: https://github.com/kmuto/review/pull/1549
[#1550]: https://github.com/kmuto/review/pull/1550
[#1551]: https://github.com/kmuto/review/pull/1551
[#1552]: https://github.com/kmuto/review/pull/1552
[#1558]: https://github.com/kmuto/review/pull/1558
[#1559]: https://github.com/kmuto/review/issues/1559
[#1560]: https://github.com/kmuto/review/pull/1560
[#1562]: https://github.com/kmuto/review/pull/1562
[#1563]: https://github.com/kmuto/review/pull/1563
[#1564]: https://github.com/kmuto/review/pull/1564
[#1569]: https://github.com/kmuto/review/pull/1569
[#1572]: https://github.com/kmuto/review/pull/1572
[#1573]: https://github.com/kmuto/review/pull/1573
[#1574]: https://github.com/kmuto/review/issues/1574
[#1584]: https://github.com/kmuto/review/pull/1584

# Version 4.2.0
## New Features
* introduce `caption_position` parameter to specify a caption position of image, table, list, and equation. `caption_position` has child parameters `image`, `table`, `list`, and `equation` and the value is `top` or `bottom` ([#1320])

## Breaking Changes
* review-vol is rewritten.  Improved processing of parts and inline instructions in headings. Changed display format. When a part is specified, the volume of the part file itself is returned instead of the volume of the part. The `-P` and `--directory` options have been removed ([#1485])
* review-index is rewritten. Most option names have been changed. The number of lines and characters are now displayed only when `-d` option is specified. review-index uses PLAINTEXTBuilder to return accurate line and character counts. `-y` option is provided to specify a target chapter ([#1485])

## Bug Fixes
* remove duplicated `@non_parsed_commands` declaration ([#1499])
* mathematical images not being created in WebMaker and TextMaker has been fixed ([#1501])

## Enhancements
* improve a performance of building math figures on imgmath ([#1488])
* for those times when you want to hand over non-default YAML parameters to PDFMaker, you can write your own `layouts/config-local.tex.erb` file ([#1505])

## Others
* GitHub Actions: use `ruby/setup-ruby` instead of `eregon/use-ruby-action` ([#1490])
* skip artifacts in the sample folder during testing ([#1504])

[#1320]: https://github.com/kmuto/review/issues/1320
[#1485]: https://github.com/kmuto/review/issues/1485
[#1488]: https://github.com/kmuto/review/issues/1488
[#1490]: https://github.com/kmuto/review/pull/1490
[#1499]: https://github.com/kmuto/review/issues/1499
[#1501]: https://github.com/kmuto/review/pull/1501
[#1504]: https://github.com/kmuto/review/pull/1504
[#1505]: https://github.com/kmuto/review/issues/1505

# Version 4.1.0
## New Features
* add `table_row_separator` to specify a separator that separates table rows. Accceptable value: tabs (means `\t+`, default), `singletab` (means `\t`), spaces (means `\s+`), verticalbar (means `\s*\|\s*`) ([#1420])
* PDFMaker, EPUBMaker, WEBMaker, TEXTMaker, IDGXMLMaker: add `-y` (`--only`) option to specify the files to convert instead of all files ([#1428])
* add `--without-config-comment` option to review-init command to exclude comments from config.yml ([#1453])
* PDFMaker: add `use_original_image_size` in `pdfmaker` section. If this parameter is set to true, images in `//image`, `//indepimage`, and `//imgtable` will be placed in actual size, not textwidth ([#1461])

## Breaking Changes
* PDFMaker: `image_scale2width` parameter has been moved under `pdfmaker` section ([#1462])

## Bug Fixes
* PDFMaker: fix backward compatibility error with Re:VIEW 3 ([#1414])
* PDFMaker: fix an error when compiling review-jlreq with LuaLaTeX ([#1416])
* PDFMaker: fix index not being included in the table of contents ([#1418])
* RSTBuilder: fix conversion failure due to incorrect method argument handling ([#1426])
* IDGXMLBuilder: there was an error in the warning handling for the table ([#1427])
* IDGXMLMaker: there was an error in the processing when an error occurred in the filter program ([#1429])
* PDFMaker: fix a build failure when using inline operators such as `@<code>` or `@<tt>` for heading with `media=ebook` mode ([#1432], [#1465])
* PDFMaker: raise just warning instead of error, when MeCab isn't installed ([#1445])
* IDGXMLBuilder: fix `//imgtable` to work correctly ([#1448])
* PDFMaker: fix an error when makeindex is true but no index is registered ([#1467])
* PDFMaker: fix missing footnotes in a description list ([#1476])
* review-index: fix an error when `@<w>` exists in headlines ([#1484])

## Enhancements
* PDFMaker: add version to .cls/.sty files ([#1163])
* update Dockerfile ([#1412])
* IDGXMLMaker: show the contents of stderr from the filter program ([#1443])
* add *-idgxml folder entry to .gitignore ([#1448])
* `//source` can now omit options in all builders ([#1447])
* add Ruby 2.7 to the test targets ([#1468])
* allow a setting of multiple word\_file ([#1469])
* EPUBMaker: warn when there is no heading in .re file ([#1474])

## Docs
* add the description about `contact` and `colophon_order` to `config.yml.sample` ([#1425])
* update quickstart.ja.md and quickstart.md to Re:VIEW 4 ([#1442])
* update syntax-book sample document ([#1448], [#1449])
* update README.md ([#1455], [#1458])
* update format.ja.md and format.md. add the description about `::` notation which sets builder-specific options to images ([#1421])

## Others
* refactor codes with Rubocop 0.78.0 ([#1424], [#1430])
* run PDF build test more strictly when there is LaTeX runtime environment ([#1433])
* switch the build test suite from Travis CI to GitHub Actions ([#1431], [#1436], [#1437])
* IDGXMLBuilder: refactor code list methods ([#1438], [#1439])
* remove unnecessary review-ext.rb from syntax-book ([#1446])
* add tests for IDGXMLMaker and TextMaker ([#1448])
* refactor around Index ([#1456], [#1457], [#1459])
* update jsclasses to version 2020/02/02 ([#1478])

## Contributors
* [@turky](https://github.com/turky)

[#1163]: https://github.com/kmuto/review/issues/1163
[#1412]: https://github.com/kmuto/review/pull/1412
[#1414]: https://github.com/kmuto/review/issues/1414
[#1416]: https://github.com/kmuto/review/issues/1416
[#1418]: https://github.com/kmuto/review/issues/1418
[#1420]: https://github.com/kmuto/review/issues/1420
[#1421]: https://github.com/kmuto/review/issues/1421
[#1424]: https://github.com/kmuto/review/pull/1424
[#1425]: https://github.com/kmuto/review/pull/1425
[#1426]: https://github.com/kmuto/review/pull/1426
[#1427]: https://github.com/kmuto/review/pull/1427
[#1428]: https://github.com/kmuto/review/pull/1428
[#1429]: https://github.com/kmuto/review/pull/1429
[#1430]: https://github.com/kmuto/review/pull/1430
[#1431]: https://github.com/kmuto/review/pull/1431
[#1432]: https://github.com/kmuto/review/issues/1432
[#1433]: https://github.com/kmuto/review/pull/1433
[#1436]: https://github.com/kmuto/review/pull/1436
[#1437]: https://github.com/kmuto/review/issues/1437
[#1438]: https://github.com/kmuto/review/pull/1438
[#1439]: https://github.com/kmuto/review/pull/1439
[#1442]: https://github.com/kmuto/review/issues/1442
[#1443]: https://github.com/kmuto/review/pull/1443
[#1445]: https://github.com/kmuto/review/pull/1445
[#1446]: https://github.com/kmuto/review/pull/1446
[#1447]: https://github.com/kmuto/review/issues/1447
[#1448]: https://github.com/kmuto/review/pull/1448
[#1449]: https://github.com/kmuto/review/pull/1449
[#1453]: https://github.com/kmuto/review/pull/1453
[#1455]: https://github.com/kmuto/review/pull/1455
[#1456]: https://github.com/kmuto/review/pull/1456
[#1457]: https://github.com/kmuto/review/pull/1457
[#1458]: https://github.com/kmuto/review/pull/1458
[#1459]: https://github.com/kmuto/review/pull/1459
[#1461]: https://github.com/kmuto/review/issues/1461
[#1462]: https://github.com/kmuto/review/issues/1462
[#1465]: https://github.com/kmuto/review/pull/1465
[#1466]: https://github.com/kmuto/review/pull/1466
[#1467]: https://github.com/kmuto/review/pull/1467
[#1468]: https://github.com/kmuto/review/pull/1468
[#1469]: https://github.com/kmuto/review/issues/1469
[#1474]: https://github.com/kmuto/review/issues/1474
[#1476]: https://github.com/kmuto/review/issues/1476
[#1478]: https://github.com/kmuto/review/issues/1478
[#1484]: https://github.com/kmuto/review/pull/1484

# Version 4.0.0
## New Features
* introduce review-idgxmlmaker which generates IDGXML files at once ([#1337])
* review-textmaker converts the math in the document to image files when `imgmath` parameter has `true` ([#1338])
* introduce wizard mode to layout of LaTeX on Web browser. Add `-w` option to review-init. This feature is experimental and may be replaced in the future ([#1403])
* experimental feature: introduce the feature to insert whitespace based on character when combining lines into a paragraph. To enable this, install unicode-eaw gem and add `join_lines_by_lang: true` into config.yml [#1362]

## Breaking Changes
* review-init no longer creates empty `layouts` folder ([#1340])
* PDFMaker: fix a problem that white space characters disappeared in `@<code>`, `@<tt>`, `@<tti>`, and `@<ttb>`. Also the string is automatically wrapped ([#1348])
* `//texequation`, `//embed` and `//graph` that don't allow inline op no longer escape inline op in strings. And don't put extra line break ([#1371], [#1374])
* PDFMaker: change the default table placement from `htp` to `H` for use in columns (`\floatplacement{table}` value in review-style.sty) [#1385]
* PDFMaker: the space between Japanese/Western characters in the code lists is changed to 0 from 1/4 character ([#1401])
* change the default value of `toc` parameter from null (false, don't create a table of contents) to true (create a table of contents) ([#1405])

## Bug Fixes
* fix a typo in review-jlreq ([#1350])
* fix incorrect result when `re` file uses CR for line-feed code ([#1341])
* PDFMaker: fix foreground color of `//cmd` with review-jlreq after page breaking ([#1363])
* PDFMaker: fix duplicate 'column' label for `@<column>` ([#1367])
* PDFMaker: copy gentombow.sty and jsbook.cls only for review-jsbook ([#1381])
* PDFMaker: fix invalid PDFDocumentInformation on review-jlreq with LuaLaTeX ([#1392])
* PDFMaker: fix missing hiddenfolio information at even pages on review-jlreq ([#1395])

## Enhancements
* support `@<em>` and `@<strong>` in IDGXMLBuilder ([#1353])
* PDFMaker: extract `code_line` and `code_line_num` from code blocks for ease handling each line ([#1368])
* PDFMaker: add new compile option `-halt-on-error` to make it easier to find the problem when an error occurs ([#1378])
* PDFMaker: when there is a footnote text (`//footnote`) in the column block, it may cuse problems such as numbering. So warn it if there is. ([#1379])
* Logger: progname should be add in logger, not in message arguments ([#1388])
* improve error checking for yaml files ([#1386])
* PDFMaker: the cover page becomes even number (p.0) and is named "cover" ([#1402])
* PDFMaker: refactor `generate_pdf` method ([#1404])
* create `.gitignore` for new project ([#1407])

## Docs
* update sample-book/README.md ([#1354])
* add descriptions about options of jsbook.cls to review-jsbook/README.md ([#1365])

## Others
* unify styles of a method with arguments ([#1360])
* `Catalog#{chaps,parts,predef,postdef,appendix}` should return Array, not String ([#1372])
* use `safe_load` for loading YAML ([#1375])
* refactor `table` method to simplify each builder ([#1356])
* refactor `XXX_header` and `XXX_body` ([#1359])
* enable `Builder#highlight?` method on each builder ([#1373])
* refactor mkdchap* and mkpart* ([#1383])
* don't update rubygems in Travis CI ([#1389])
* refactor around Index ([#1390])
* add configration for review-jlreq to sample documents ([#1391])
* definition list should start with spaces ([#1398])

## Contributors
* [@m-shibata](https://github.com/m-shibata)
* [@masarakki](https://github.com/masarakki)

[#1337]: https://github.com/kmuto/review/issues/1337
[#1338]: https://github.com/kmuto/review/issues/1338
[#1340]: https://github.com/kmuto/review/issues/1340
[#1341]: https://github.com/kmuto/review/issues/1341
[#1348]: https://github.com/kmuto/review/issues/1348
[#1350]: https://github.com/kmuto/review/issues/1350
[#1353]: https://github.com/kmuto/review/pull/1353
[#1354]: https://github.com/kmuto/review/pull/1354
[#1356]: https://github.com/kmuto/review/pull/1356
[#1359]: https://github.com/kmuto/review/pull/1359
[#1360]: https://github.com/kmuto/review/pull/1360
[#1362]: https://github.com/kmuto/review/pull/1362
[#1363]: https://github.com/kmuto/review/issues/1363
[#1365]: https://github.com/kmuto/review/pull/1365
[#1367]: https://github.com/kmuto/review/issues/1367
[#1368]: https://github.com/kmuto/review/issues/1368
[#1371]: https://github.com/kmuto/review/pull/1371
[#1372]: https://github.com/kmuto/review/pull/1372
[#1373]: https://github.com/kmuto/review/pull/1373
[#1374]: https://github.com/kmuto/review/pull/1374
[#1375]: https://github.com/kmuto/review/pull/1375
[#1378]: https://github.com/kmuto/review/pull/1378
[#1379]: https://github.com/kmuto/review/issues/1379
[#1381]: https://github.com/kmuto/review/issues/1381
[#1383]: https://github.com/kmuto/review/issues/1383
[#1385]: https://github.com/kmuto/review/issues/1385
[#1386]: https://github.com/kmuto/review/pull/1386
[#1388]: https://github.com/kmuto/review/pull/1388
[#1389]: https://github.com/kmuto/review/pull/1389
[#1390]: https://github.com/kmuto/review/pull/1390
[#1391]: https://github.com/kmuto/review/pull/1391
[#1392]: https://github.com/kmuto/review/issues/1392
[#1395]: https://github.com/kmuto/review/issues/1395
[#1398]: https://github.com/kmuto/review/issues/1398
[#1401]: https://github.com/kmuto/review/pull/1401
[#1402]: https://github.com/kmuto/review/pull/1402
[#1403]: https://github.com/kmuto/review/pull/1403
[#1404]: https://github.com/kmuto/review/pull/1404
[#1405]: https://github.com/kmuto/review/pull/1405
[#1407]: https://github.com/kmuto/review/pull/1407

# Version 3.2.0

## Breaking Changes
* PDFMaker: changed to use the abstract name `\reviewincludegraphics` instead of `\includegraphics` for image placements (such as `//image`) ([#1318])

## Bug Fixes
* reference to IDs of non-existent chapter now return standard key error (instead of internal error) ([#1284])
* fixed the value in the error message of review-compile ([#1286])
* PDFMaker: fixed the metadata of PDF page number was wrong when using review-jsbook with serial_pagination = true ([#1288])
* fixed a bug when using `@<hd>` to refer to headings with notoc, nodisp, or nonum ([#1294])
* PDFMaker: fixed an error in review-jlreq when using jlreq.cls version 0401 ([#1298])
* EPUBMaker: fixed a error of building EPUB2 ([#1301])
* EPUBMaker: added a workaround for a temporary folder deletion failure on Windows ([#1011])
* PDFMaker: support `@<bou>` ([#1220])
* PDFMaker: support old jlreq.cls ([#1317])

## Enhancements
* added test when `CHAPS:` is empty ([#1275])
* PDFMaker: for safety, inline typeface commands such as `\reviewtt` are defined with RobustCommand ([#1280])
* EPUBMaker: added `--debug` option to execute in debug mode ([#1281])
* review-epub2html: added `--inline-footnote` option to represent footnotes as inline ([#1283])
* EPUBMaker: added metadata of the cover image on EPUB3 for iBooks ([#1293])
* PDFMaker: suppressed the unexptected page break after the caption of code list or equation in review-jsbook and review-jlreq ([#1299])
* reformatted the codes using rubocop 0.67.2 ([#1297])
* added a test of building EPUB ([#1300])
* updated Ruby versions of test target to 2.4.6, 2.5.5, and 2.6.3 ([#1303])
* improved the code of YAMLLoader ([#1304])
* raise an error when invalid level is used in bullet ([#1313])
* extracted ReVIEW::Location class ([#1308])
* avoid multi-lined English words being combined without a space in bullets and bibliographic list (only in PDFMaker, at this time) ([#1312])
* raise an error when table is empty ([#1325])
* add some tests ([#1327], [#1328])
* MARKDOWNBilder: support `//listnum` ([#1336])

## Docs
* fixed the description about header levels ([#1309])

## Others
* removed ReVIEW::Preprocessor::Strip due to it is no longer used ([#1305])

## Contributors
* [@uetchy](https://github.com/uetchy)
* [@mitsuo0114](https://github.com/mitsuo0114)

[#1011]: https://github.com/kmuto/review/issues/1011
[#1220]: https://github.com/kmuto/review/issues/1220
[#1275]: https://github.com/kmuto/review/pull/1275
[#1280]: https://github.com/kmuto/review/pull/1280
[#1281]: https://github.com/kmuto/review/issues/1281
[#1283]: https://github.com/kmuto/review/pull/1283
[#1284]: https://github.com/kmuto/review/issues/1284
[#1286]: https://github.com/kmuto/review/pull/1286
[#1288]: https://github.com/kmuto/review/issues/1288
[#1293]: https://github.com/kmuto/review/pull/1293
[#1294]: https://github.com/kmuto/review/issues/1294
[#1297]: https://github.com/kmuto/review/pull/1297
[#1298]: https://github.com/kmuto/review/pull/1298
[#1299]: https://github.com/kmuto/review/pull/1299
[#1300]: https://github.com/kmuto/review/pull/1300
[#1301]: https://github.com/kmuto/review/pull/1301
[#1303]: https://github.com/kmuto/review/pull/1303
[#1304]: https://github.com/kmuto/review/pull/1304
[#1305]: https://github.com/kmuto/review/pull/1305
[#1308]: https://github.com/kmuto/review/pull/1308
[#1309]: https://github.com/kmuto/review/issues/1309
[#1312]: https://github.com/kmuto/review/issues/1312
[#1313]: https://github.com/kmuto/review/issues/1313
[#1317]: https://github.com/kmuto/review/pull/1317
[#1318]: https://github.com/kmuto/review/issues/1318
[#1325]: https://github.com/kmuto/review/issues/1325
[#1327]: https://github.com/kmuto/review/issues/1327
[#1328]: https://github.com/kmuto/review/pull/1328
[#1336]: https://github.com/kmuto/review/pull/1336

# Version 3.1.0
## Breaking Changes
* PDFMaker: introduce `\reviewimagecaption` macro for the caption of figure ([#1254]). Please update your review-base.sty by `review-update` command on your  Re:VIEW 3 project.
* remove `--strip` option which is undocumented and doesn't work correctly from `review-preproc command` ([#1257])

## Bug Fixes
* PDFMaker: fix a problem that the section number of the part continues the section number in the previous chapter ([#1225],[#1226])
* fix copying of gentombow.sty in samples folder ([#1229])
* PDFMaker: fix that the number of lines specified by `number_of_lines` document option decrease by 1 line than originally on review-jsbook ([#1235])
* PDFMaker: fix review-jlreq to work with LuaLaTeX ([#1243])
* EPUBMaker: fix a problem that the hierachy of the table of contents become strange when there is a part ([#1262])
* fix escaping of `//comment` ([#1264])
* PDFMaker: fix overflowing when the left column of colophon is long ([#1252])
* fix an error when CHAPS: is empty ([#1273])

## Enhancements
* PDFMaker: load amssymb, amsthm, and bm packages which are often used as extension of mathematical expression ([#1224])
* HTMLBuilder: `emlist` and `listnum` now always pass `highlight` method as well as others ([#1231])
* EPUBMaker: implement a back-link to the text from the footnote ([#1233])
* PDFMaker: add `\makelines` macro to create a dummy line ([#1240])
* implement `#@warn` correctly ([#1258])
* `#@mapfile` now imports as is (keep tabs etc.) when imported file has `.re` extension ([#1247])
* add Ruby 2.6 for the test coverage ([#1242])
* PDFMaker: replace `zw` with `\zw` in review-jlreq. add a indent to paragraphs in the column ([#1250])
* PDFMaker: when `\reviewimagecaption` is undefined (implemented in [#1254]), define it ([#1267])

## Docs
* README.md: fix the filename of jsbook.cls ([#1239])
* add the note about `back_footnote` into config.yml.sample and update documents a little ([#1268])

## Contributors
* [@doublemarket](https://github.com/doublemarket)
* [@munepi](https://github.com/munepi)

[#1224]: https://github.com/kmuto/review/issues/1224
[#1225]: https://github.com/kmuto/review/pull/1225
[#1226]: https://github.com/kmuto/review/pull/1226
[#1229]: https://github.com/kmuto/review/pull/1229
[#1231]: https://github.com/kmuto/review/issues/1231
[#1233]: https://github.com/kmuto/review/issues/1233
[#1235]: https://github.com/kmuto/review/issues/1235
[#1239]: https://github.com/kmuto/review/pull/1239
[#1240]: https://github.com/kmuto/review/pull/1240
[#1242]: https://github.com/kmuto/review/pull/1242
[#1243]: https://github.com/kmuto/review/issues/1243
[#1247]: https://github.com/kmuto/review/issues/1247
[#1250]: https://github.com/kmuto/review/pull/1250
[#1252]: https://github.com/kmuto/review/issues/1252
[#1254]: https://github.com/kmuto/review/issues/1254
[#1257]: https://github.com/kmuto/review/issues/1257
[#1258]: https://github.com/kmuto/review/issues/1258
[#1262]: https://github.com/kmuto/review/issues/1262
[#1264]: https://github.com/kmuto/review/issues/1264
[#1267]: https://github.com/kmuto/review/issues/1267
[#1268]: https://github.com/kmuto/review/issues/1268
[#1273]: https://github.com/kmuto/review/issues/1273

# Version 3.0.0

## Bug Fixes
* PDFMaker: adjust the loading of external files in review-jsbook.cls ([#1217])

## Contributors
* [@munepi](https://github.com/munepi)

[#1217]: https://github.com/kmuto/review/pull/1217

# Version 3.0.0 release candidate
## Breaking Changes
* PDFMaker: heading character size of review-jsbook becomes the same as the original jsbook ([#1152])
* PDFMaker: Q, W, L, H parameters of review-jsbook are withdrawn. Projects created in the past preview version can be updated with the review-update command ([#1151],[#1201])

## Bug Fixes
* PDFMaker: fixes an issue that hiddenfolio parameter was ignored when using both hiddenfolio and tombopaper in review-jsbook ([#1158])
* PDFMaker: fixes a problem that the paperwidth and paperheight parameters of review-jsbook didn't work ([#1171])
* fixes an issue that review-update ignored update of sty folder ([#1183])
* PDFMaker: fix serial_pagination and startpage were not working in review-jlreq class ([#1204])

## Enhancements
* PDFMaker: in review-jsbook, you can specify the font size with `fontsize` parameter and the line height with `baselineskip` parameter with units such as pt and mm ([#1151])
* PDFMaker: users who want to continue using the original jsbook.cls class file for some reason can use sty files of review-jsbook set ([#1177])
* PDFMaker: add useful macros to review-jsbook and review-jlreq for users. `\oneblankpage` creates an empty page. `\clearoddpage` breaks page as necessary so that the next page is always an even page ([#1175],[#1182])
* PDFMaker: add `media` parameter that specifies the type of PDF to review-jsbook and review-jlreq. This has the same meaning as `cameraready` ([#1181])
* PDFMaker: sections are now allowed in part ([#1195])
* PDFMaker: `\reviewusepart` macro is defined when theare is a part ([#1199])
* `texdocumentclass` parameter is explicit (not a comment) when creating config.yml by review-init ([#1202])
* PDFMaker: line feed (`@<br>`) in the table is now represented by `\newline` macro when the width is explicity specified with `//tsize` ([#1206])
* PDFMaker: enable to use `L{width}` (left justified), `C{width}` (centering), `R{width}` (right justified) as representation of the table column width ([#1208])
* PDFMaker: to avoid implementation differences between versions, the snapshots jsbook.cls (2018/06/23) and gentombow.sty (2018/08/30 v0.9j) are copied to the `sty` folder ([#1210])

## Docs
* update `format_idg.ja.md` ([#1188])
* add note about review-update command to quickstart guide `quickstart.ja.md` ([#1189])
* update comments of `config.yml.sample` ([#1190])
* update `pdfmaker.ja.md` ([#1191])
* update `writing_vertical.ja.md`  ([#1198])
* update document of review-jsbook ([#1203])
* update document of review-jlreq ([#1204])

## Contributors
* [@munepi](https://github.com/munepi)

[#1151]: https://github.com/kmuto/review/issues/1151
[#1152]: https://github.com/kmuto/review/issues/1152
[#1158]: https://github.com/kmuto/review/issues/1158
[#1171]: https://github.com/kmuto/review/issues/1171
[#1175]: https://github.com/kmuto/review/pull/1175
[#1177]: https://github.com/kmuto/review/pull/1177
[#1181]: https://github.com/kmuto/review/issues/1181
[#1182]: https://github.com/kmuto/review/pull/1182
[#1183]: https://github.com/kmuto/review/issues/1183
[#1188]: https://github.com/kmuto/review/pull/1188
[#1189]: https://github.com/kmuto/review/pull/1189
[#1190]: https://github.com/kmuto/review/pull/1190
[#1191]: https://github.com/kmuto/review/pull/1191
[#1195]: https://github.com/kmuto/review/issues/1195
[#1198]: https://github.com/kmuto/review/pull/1198
[#1199]: https://github.com/kmuto/review/pull/1199
[#1201]: https://github.com/kmuto/review/pull/1201
[#1202]: https://github.com/kmuto/review/pull/1202
[#1203]: https://github.com/kmuto/review/pull/1203
[#1204]: https://github.com/kmuto/review/pull/1204
[#1206]: https://github.com/kmuto/review/issues/1206
[#1208]: https://github.com/kmuto/review/pull/1208
[#1210]: https://github.com/kmuto/review/issues/1210

# Version 3.0.0 preview 4
## New Features
* new command `review-update` is added, which updates the setting of the project files to the new version ([#1144])
* `texequation` representing an expression can now be numbered and captioned.  To reference this you can use the `@<eq>` operator ([#1167])

## Breaking Changes
* In IDGXMLBuilder, PlaintextBuilder, and TextBuilder, the expansion result of `@<chapref>` is no longer created in a unique way. Like other builders, it uses the `chapter_quote` locale string ([#1160])

## Bug Fixes
* samples collection could not generate PDF in preview 3. Now it works with `rake pdf` ([#1156])

## Enhancements
* PDFMaker: support hiddenfolio parameter with review-jlreq.cls ([#1147])
* EPUBMaker/WEBMaker: when imgmath function is enabled, font size is passed to each `//texequation` ([#1146])

[#1144]: https://github.com/kmuto/review/issues/1144
[#1146]: https://github.com/kmuto/review/issues/1146
[#1147]: https://github.com/kmuto/review/issues/1147
[#1156]: https://github.com/kmuto/review/issues/1156
[#1160]: https://github.com/kmuto/review/issues/1160
[#1167]: https://github.com/kmuto/review/issues/1167

# Version 3.0.0 preview 3
## New Features
* PDFMaker: instead of using jsbook.cls as it is, review-jsbook.cls (based on jsbook.cls, default) and review-jlreq.cls (based on jlreq.cls) are introduced. These supports the creation both paper and electronic PDF books. ([#1032],[#1117])
* EPUBMaker/WEBMaker: add imgmath function to image mathematical expressions ([#868],[#1138])

## Breaking Changes
* PDFMaker: the location of `\frontmatter` is moved from the back of the titlepage to the front ([#1128])
* PDFMaker: the cover image specified by `coverimage` is placed in the actual size and in the center ([#1064],[#1117])

## Bug Fixes
* PDFMaker: fix an errror handling of `cover` parameter ([#1116])
* PDFMaker: fix position misalignment in preview 2 ([#1090],[#1117])

## Enhancements
* PDFMaker: increase the number of `config.yml` configuration parameters to LaTeX macros ([#1121])
* PDFMaker: add hook `\reviewbegindocumenthook` just after `\begin{document}`, and add hook `\reviewenddocumenthook` just before `\end{document}` ([#1111])
* PDFMaker: geometry.sty is no longer used, because the new class file can specify the paper design by document option ([#912])
* PDFMaker: serial-pagination feature is supported in new class files ([#1129])
* add network download function to `review-init` command. Specifying the URL of the zip file with `-p` option expands the zip file to the project folder ([#812])
* PDFMaker: For expressing digital trim-marks and hidden page numbers (kakushi-nombre), the gentombow package (the external TeX package) has been included in vendor folder. It will be copied to the sty folder of the project folder ([#1136])

## Docs
* add a method of making Kindle e-book file to doc/customize_epub.ja.md ([#1114])
* update examples of PDFMaker's default document options ([#1115])
* clarify license of each file ([#1093],[#1112])
* add note about `imgmath` feature to doc/format.ja.md ([#868])

## Contributors
* [@munepi](https://github.com/munepi)

[#812]: https://github.com/kmuto/review/issues/812
[#868]: https://github.com/kmuto/review/issues/868
[#912]: https://github.com/kmuto/review/issues/912
[#1032]: https://github.com/kmuto/review/issues/1032
[#1064]: https://github.com/kmuto/review/issues/1064
[#1090]: https://github.com/kmuto/review/issues/1090
[#1093]: https://github.com/kmuto/review/issues/1093
[#1111]: https://github.com/kmuto/review/pull/1111
[#1112]: https://github.com/kmuto/review/pull/1112
[#1114]: https://github.com/kmuto/review/pull/1114
[#1115]: https://github.com/kmuto/review/issues/1115
[#1116]: https://github.com/kmuto/review/pull/1116
[#1117]: https://github.com/kmuto/review/pull/1117
[#1121]: https://github.com/kmuto/review/pull/1121
[#1128]: https://github.com/kmuto/review/issues/1128
[#1129]: https://github.com/kmuto/review/pull/1129
[#1136]: https://github.com/kmuto/review/issues/1136
[#1138]: https://github.com/kmuto/review/issues/1138

# Version 3.0.0 preview 2

## New Features
* add `review-epub2html` to produce single HTML file from EPUB file for CSS typesetting ([#1098])

## Breaking Changes
* PDFMaker: allow a path with space character on `texcommand`, `dvicommmand`, and `makeindex_command`. Due to this change, these parameters no longer take command options. use `texoptions`, `dvioptions`, and `makeindex_options` to specify  options ([#1091])
* PDFMaker: the file used internally has been changed from `book.tex` to `__REVIEW_BOOK__.tex` ([#1081])
* PDFMaker: dropped geometry.sty from jsbook style ([#912])
* PDFMaker: use twocolumn option for jsbook style ([#1032])
* unified strings expanded by `@<chapref>`, `@<hd>`, and `@<column>` op between builders. you can customize it with `locale.yml`. `@<chapref>` will be expanded like `Chapter 1 "FOO"` (locale msgid: `chapter_quote` and `chapter_quote_without_number`). `chapter_quote` now takes two `%s`. `@<hd>` will be expanded like `"2.1 BAR"` (locale msgid: `hd_quote` and `hd_quote_without_number`). `@<column>` will be extended like `Column BAZ` (locale msgid: `column`) ([#886])

## Bug Fixes
* EPUBMaker: `modified` value of OPF file is now correct UTC time ([#1094])
* fix an issue where bibliography file in `contentdir` could not be read ([#1103])
* PDFMaker: fix an issue where the file specified by the parameter could not be found ([#1086])
* fix a bug in the fence escaping that occurred in preview1 ([#1083])
* remove unwanted tab character from sample CSS ([#1084])

## Enhancements
* PDFMaker: use `\floatplacement` to configure float settings of table and figure ([#1095])
* EPUBMaker: use logger function to export error/warning ([#1077])
* PDFMaker: do not use dvipdfmx when `dvicommand` parameter is null ([#1065])

## Docs
* Move sample documents to /samples folder ([#1073])
* Add descriptions abount hooks and parameters of indexing into `config.yml.sample` ([#1097])
* Fix typo in quickstart.md ([#1079])

## Contributors
* [@aiya000](https://github.com/aiya000)
* [@sho-h](https://github.com/sho-h)
* [@kateinoigakukun](https://github.com/kateinoigakukun)

[#886]: https://github.com/kmuto/review/issues/886
[#912]: https://github.com/kmuto/review/issues/912
[#1032]: https://github.com/kmuto/review/issues/1032
[#1065]: https://github.com/kmuto/review/pull/1065
[#1073]: https://github.com/kmuto/review/issues/1073
[#1077]: https://github.com/kmuto/review/pull/1077
[#1079]: https://github.com/kmuto/review/pull/1079
[#1081]: https://github.com/kmuto/review/pull/1081
[#1080]: https://github.com/kmuto/review/issues/1080
[#1083]: https://github.com/kmuto/review/issues/1083
[#1084]: https://github.com/kmuto/review/pull/1084
[#1086]: https://github.com/kmuto/review/issues/1086
[#1091]: https://github.com/kmuto/review/pull/1091
[#1094]: https://github.com/kmuto/review/pull/1094
[#1095]: https://github.com/kmuto/review/pull/1095
[#1097]: https://github.com/kmuto/review/pull/1097
[#1098]: https://github.com/kmuto/review/pull/1098
[#1103]: https://github.com/kmuto/review/pull/1103

# Version 3.0.0 preview 1

## New Features
* .re files can be placed in subfolders by specifying a folder with `contentdir` parameter ([#920])
* `//graph` supports PlantUML ([#1006])
* add `@<w>` and `@<wb>` to expand the value corresponding to the specified key from CSV word file ([#1007], [#1010])
* LATEXBuilder: raise error when `*.re` file in catalog.yml does not exist ([#957])
* LATEXBuilder: add pxrubrica package to support 'ruby' ([#655])
* LATEXBuilder: support multiple layout files for LaTeX style ([#812])
* support inline `@<balloon>` as default settings ([#829])
* LATEXBuilder: allow to use Unicode character without otf package if possible  ([#1045])
* override `CONFIG_FILE` in Rakefile with rake options ([#1059])

## Breaking Changes
* When the value of review_version is 3 or more, `@<m>` no longer add a space before and after formula ([#943])
* the function of automatic detection of highlight target language by identifier in `//list`, `//listnum` is removed from HTMLBuilder ([#1016])
* LATEXBuilder: restructured `layout.tex.erb` ([#950])
* LATEXBuilder: add a new envirionment `reviewlistblock` in LaTeX ([#916])
* LATEXBuilder: attach `plistings` package and suport it instead of jlisting  for `listings` ([#635])
* LATEXBuilder: remove underline in anchor for printing use ([#808])
* LATEXBuilder: use more abstract name like `\reviewbold` instead of `\textbf` ([#792])
* LATEXBuilder: `cover` and `titlepage` in config.yml is independently of each other ([#848])
* review-preproc: remove deprecated option --final  ([#993])
* LATEXBuilder: captionblocks use new environments like `reviewnote`, not `reviewminicolumn` ([#1046])

## Bug Fixes
* Fix redundant log display with Ruby 2.3 or later ([#975])
* for backward compatibility, revert `usepackage` parameter which was removed Version 2.5.0 ([#1001])
* HTMLBuilder: hide latex log of `@<m>{...}` amd `//texequation{...//}` ([#1027])
* LATEXBuilder: fix empty caption for listings ([#1040])
* fix load path of MeCab ([#1063])

## Enhancements
* `//graph` now works on Windows ([#1008])
* file extensions of image files and font files becomes case insensitive ([#1002])
* review-pdfmaker: show executed command and its options ([#962],[#968])
* PDFMaker: support `*.psd` files as images ([#879])
* PDFMaker: `texoptions` in config.yml is "-interaction=nonstopmode -file-line-error" as default ([#1029])
* hide (latex and other commands') log messages ([#1036])
* MARKDOWNBuilder: support some commands ([#881])
* image_finder.rb: support symlinked directory ([#743])
* add files like `catalog.yml` as denendency relation ([#1060])

## Docs
* add description of external tools used in `//graph` ([#1008])
* add description of `@<w>` and `@<wb>` ([#1007])
* add description of dvipdfmx option for zlib compression level (-z 9) in config.yml ([#935])

## Contributors
* [@TeTiRoss](https://github.com/TeTiRoss)
* [@kauplan](https://github.com/kauplan)
* [@munepi](https://github.com/munepi)
* [@m-shibata](https://github.com/m-shibata)

[#635]: https://github.com/kmuto/review/issues/635
[#655]: https://github.com/kmuto/review/issues/655
[#743]: https://github.com/kmuto/review/issues/743
[#792]: https://github.com/kmuto/review/issues/792
[#808]: https://github.com/kmuto/review/issues/808
[#812]: https://github.com/kmuto/review/issues/812
[#829]: https://github.com/kmuto/review/issues/829
[#848]: https://github.com/kmuto/review/issues/848
[#879]: https://github.com/kmuto/review/issues/879
[#881]: https://github.com/kmuto/review/issues/881
[#916]: https://github.com/kmuto/review/issues/916
[#920]: https://github.com/kmuto/review/issues/920
[#938]: https://github.com/kmuto/review/issues/938
[#935]: https://github.com/kmuto/review/issues/935
[#943]: https://github.com/kmuto/review/issues/943
[#950]: https://github.com/kmuto/review/issues/950
[#957]: https://github.com/kmuto/review/issues/957
[#962]: https://github.com/kmuto/review/issues/962
[#968]: https://github.com/kmuto/review/issues/968
[#975]: https://github.com/kmuto/review/issues/975
[#993]: https://github.com/kmuto/review/issues/993
[#1001]: https://github.com/kmuto/review/pull/1001
[#1002]: https://github.com/kmuto/review/issues/1002
[#1006]: https://github.com/kmuto/review/issues/1006
[#1007]: https://github.com/kmuto/review/issues/1007
[#1008]: https://github.com/kmuto/review/pull/1008
[#1010]: https://github.com/kmuto/review/pull/1010
[#1016]: https://github.com/kmuto/review/issues/1016
[#1022]: https://github.com/kmuto/review/issues/1022
[#1027]: https://github.com/kmuto/review/issues/1027
[#1029]: https://github.com/kmuto/review/issues/1029
[#1036]: https://github.com/kmuto/review/issues/1036
[#1040]: https://github.com/kmuto/review/issues/1040
[#1045]: https://github.com/kmuto/review/issues/1045
[#1046]: https://github.com/kmuto/review/issues/1046
[#1059]: https://github.com/kmuto/review/issues/1059
[#1060]: https://github.com/kmuto/review/issues/1060
[#1063]: https://github.com/kmuto/review/issues/1063

# Version 2.5.0

## New Features

* add a new maker command `review-textmaker` to output plain text files ([#926])
* LATEXBuilder: add a new parameter `pdfmaker/bbox` for settings of BoudingBox ([#947])
* add a new command `//blankline` ([#942])

## Breaking Changes

* remove (incomplete) command `//include` ([#887])
* LATEXBuilder: use `\footnotemark` implicitly for captions and headings ([#841])
* EPUBMaker, WEBMaker: use `pbl` (publisher) instead of `prt` (printer) in titlepage ([#927])
* PDFMaker: use `texstyle` parameter instead of `usepackage` in layout.tex.erb. When using your own layout.tex.erb, you need to rewrite it with a new code of texstyle parsing. ([#908])

## Bug Fixes

* fix column closing ([#894])
* fix internal errors in `@<hd>` ([#896])
* LATEXBuilder: fix to ignore empty caption ([#922])
* fix invalid commmand errors in `//graph` when using gnuplot ([#931])
* fix errors of `review` command in Windows ([#940])
* EPUBMaker: fix error of removing temporary files in Windows ([#946])

## Enhancements

* remove tailing empty lines in block (captionblocks) such as `//note`. ([#882])
* fix error messages when using non-existent ID of catalog.yml in inline commands such as `@<chap>` ([#891])
* ignore UTF-8 BOM in catalog.yml ([#899])
* LATEXBuilder: fix a length of horizontal line in colophon ([#907])
* allow to use multiple parameters of `texstyle` in config.yml ([#908])
* review-init: create `lib/tasks` folder to use original Rake commands ([#921])
* review-init: copy `doc` folder into the target project ([#918])
* add a help message of `review` ([#933])
* show appropriate error messages when using invalid or non-existent YAML files ([#958])
* show better error messages when using unknown ID in inline commands such as `@<img>` and `@<table>` ([#954])
* show better error messages when compiling a file not included in catalog.yml ([#953])
* LATEXBuilder: add IDs of `table`, `imgtable`, `image` and `indepimage` as comments (ex. `\begin{reviewimage}%%sampleimg`) ([#937])

## Docs

* add the rule of searching image files with extension ([#939])
* add description of `review-textmaker` ([#944])

## Contributors

* [@kauplan](https://github.com/kauplan)
* [@krororo](https://github.com/krororo)
* [@mhidaka](https://github.com/mhidaka)
* [@Pegasus204](https://github.com/Pegasus204)

[#841]: https://github.com/kmuto/review/issues/841
[#882]: https://github.com/kmuto/review/issues/882
[#887]: https://github.com/kmuto/review/issues/887
[#891]: https://github.com/kmuto/review/issues/891
[#894]: https://github.com/kmuto/review/pull/894
[#896]: https://github.com/kmuto/review/issues/896
[#899]: https://github.com/kmuto/review/issues/899
[#907]: https://github.com/kmuto/review/pull/907
[#908]: https://github.com/kmuto/review/pull/908
[#918]: https://github.com/kmuto/review/issues/918
[#921]: https://github.com/kmuto/review/issues/921
[#922]: https://github.com/kmuto/review/pull/922
[#926]: https://github.com/kmuto/review/issues/926
[#927]: https://github.com/kmuto/review/pull/927
[#931]: https://github.com/kmuto/review/pull/931
[#933]: https://github.com/kmuto/review/issues/933
[#937]: https://github.com/kmuto/review/pull/937
[#939]: https://github.com/kmuto/review/pull/939
[#940]: https://github.com/kmuto/review/issues/940
[#942]: https://github.com/kmuto/review/issues/942
[#944]: https://github.com/kmuto/review/pull/944
[#946]: https://github.com/kmuto/review/issues/946
[#947]: https://github.com/kmuto/review/pull/947
[#953]: https://github.com/kmuto/review/issues/953
[#954]: https://github.com/kmuto/review/issues/954
[#958]: https://github.com/kmuto/review/issues/958

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

* allow block `{ ... //}` in `//indepimage`. ([#802])
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
[#794]: https://github.com/kmuto/review/issues/794
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
    * `prt` is printer(`印刷所`), not publisher(`発行所`).  `発行所` is `pbl`.  ([#562], [#593])
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

[#465]: https://github.com/kmuto/review/issues/465
[#473]: https://github.com/kmuto/review/issues/473

# Version 1.7.1

## Bug Fix
* Fix latexbuilder to display caption twice in `//listnum` ([#465])
* Fix review-init to generate non-valid EPUB3 file with epubcheck 4.0.1 ([#456])
[#456]: https://github.com/kmuto/review/issues/473

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
