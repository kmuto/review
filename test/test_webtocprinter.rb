require 'test_helper'
require 'review/webtocprinter'
require 'book_test_helper'

class WEBTOCPrinterTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def test_webtocprinter_null
    dummy_book = ReVIEW::Book::Base.load
    chap = ReVIEW::Book::Chapter.new(dummy_book, 1, '-', nil, StringIO.new)
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
                 'ch2.re' => "= ch. 2\n\n222\n" do |dir, book, files|
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
                 'ch2.re' => "= ch. 2\n\n222\n" do |dir, book, files|
      str = WEBTOCPrinter.book_to_string(book)
      expect = <<-EOB
<ul class="book-toc">
<li><a href="index.html">TOP</a></li>
<li>1 part1
<ul>
<li><a href="./ch1.html">1 ch. 1</a></li>
</ul>
</li>
<li>2 part2
<ul>
<li><a href="./ch2.html">2 ch. 2</a></li>
</ul>
</li>
</ul>
EOB
      assert_equal expect, str
    end
  end

end
