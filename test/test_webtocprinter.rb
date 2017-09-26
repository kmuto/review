require 'test_helper'
require 'review/webtocprinter'
require 'book_test_helper'

class WEBTOCPrinterTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def setup
    I18n.setup
  end

  def test_webtocprinter_null
    dummy_book = ReVIEW::Book::Base.load
    # chap = ReVIEW::Book::Chapter.new(dummy_book, 1, '-', nil, StringIO.new)
    str = WEBTOCPrinter.book_to_string(dummy_book)
    expect = <<-EOB
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
</ul>
EOB
    assert_equal expect, str
  end

  def test_webtocprinter_with_chapters
    catalog_yml = <<-EOB
CHAPS:
  - ch1.re
  - ch2.re
EOB
    mktmpbookdir 'catalog.yml' => catalog_yml,
                 'ch1.re' => "= ch. 1\n\n111\n",
                 'ch2.re' => "= ch. 2\n\n222\n" do |_dir, book, _files|
      str = WEBTOCPrinter.book_to_string(book)
      expect = <<-EOB
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
<li><a href="./ch1.html">1 ch. 1</a></li>
<li><a href="./ch2.html">2 ch. 2</a></li>
</ul>
EOB
      assert_equal expect, str
    end
  end

  def test_webtocprinter_with_parts
    catalog_yml = <<-EOB
CHAPS:
  - part1:
    - ch1.re
  - part2:
    - ch2.re
EOB
    mktmpbookdir 'catalog.yml' => catalog_yml,
                 'ch1.re' => "= ch. 1\n\n111\n",
                 'ch2.re' => "= ch. 2\n\n222\n" do |_dir, book, _files|
      str = WEBTOCPrinter.book_to_string(book)
      expect = <<-EOB
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
<li>I part1
<ul>
<li><a href="./ch1.html">1 ch. 1</a></li>
</ul>
</li>
<li>II part2
<ul>
<li><a href="./ch2.html">2 ch. 2</a></li>
</ul>
</li>
</ul>
EOB
      assert_equal expect, str
    end
  end

  def test_webtocprinter_with_partfiles
    catalog_yml = <<-EOB
CHAPS:
  - p1.re:
    - ch1.re
  - p2.re:
    - ch2.re
EOB
    mktmpbookdir 'catalog.yml' => catalog_yml,
                 'p1.re' => "= This is PART1\n\np111\n",
                 'p2.re' => "= This is PART2\n\np111\n",
                 'ch1.re' => "= ch. 1\n\n111\n",
                 'ch2.re' => "= ch. 2\n\n222\n" do |_dir, book, _files|
      str = WEBTOCPrinter.book_to_string(book)
      expect = <<-EOB
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
<li><a href="p1.html">I This is PART1</a>
<ul>
<li><a href="./ch1.html">1 ch. 1</a></li>
</ul>
</li>
<li><a href="p2.html">II This is PART2</a>
<ul>
<li><a href="./ch2.html">2 ch. 2</a></li>
</ul>
</li>
</ul>
EOB
      assert_equal expect, str
    end
  end

  def test_webtocprinter_full
    catalog_yml = <<-EOB
PREDEF:
  - pre1.re
  - pre2.re
CHAPS:
  - part1.re:
    - ch1.re
  - part2.re:
    - ch2.re
APPENDIX:
  - app1.re
  - app2.re
POSTDEF:
  - post1.re
  - post2.re
EOB
    mktmpbookdir 'catalog.yml' => catalog_yml,
                 'pre1.re' => "= PRE1\n\npre111\n",
                 'pre2.re' => "= PRE2\n\npre222\n",
                 'app1.re' => "= APP1\n\napp111\n",
                 'app2.re' => "= APP2\n\napp222\n",
                 'part1.re' => "= PART1\n\np111\n",
                 'part2.re' => "= PART2\n\np111\n",
                 'post1.re' => "= POST1\n\npo111\n",
                 'post2.re' => "= POST2\n\npo222\n",
                 'ch1.re' => "= ch. 1\n\n111\n",
                 'ch2.re' => "= ch. 2\n\n222\n" do |_dir, book, _files|
      str = WEBTOCPrinter.book_to_string(book)
      expect = <<-EOB
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
<li><a href="./pre1.html">PRE1</a></li>
<li><a href="./pre2.html">PRE2</a></li>
<li><a href="part1.html">I PART1</a>
<ul>
<li><a href="./ch1.html">1 ch. 1</a></li>
</ul>
</li>
<li><a href="part2.html">II PART2</a>
<ul>
<li><a href="./ch2.html">2 ch. 2</a></li>
</ul>
</li>
<li><a href="./app1.html">APP1</a></li>
<li><a href="./app2.html">APP2</a></li>
<li><a href="./post1.html">POST1</a></li>
<li><a href="./post2.html">POST2</a></li>
</ul>
EOB
      assert_equal expect, str
    end
  end
end
