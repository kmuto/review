require 'book_test_helper'
require 'review/book/bibliography'

class BibliographyTest < Test::Unit::TestCase
  include BookTestHelper
  def setup
    mktmpbookdir do |_dir, book, _files|
      @book = book
    end
    @bib = Book::Bibliography.new(bibfile, @book.config)
  end

  def test_new
    assert @bib
  end

  def test_ref_text
    @book.config['bib-csl-style'] = 'acm-siggraph'
    assert_equal '[Thomas et al. 2009]', @bib.format('text').ref('pickaxe')

    @book.config['bib-csl-style'] = 'apa'
    assert_equal '(Thomas et al., 2009)', @bib.format('text').ref('pickaxe')

    @book.config['bib-csl-style'] = 'ieee'
    assert_equal '[1]', @bib.format('text').ref('pickaxe')
  end

  def test_ref_text_multiple
    @book.config['bib-csl-style'] = 'acm-siggraph'
    assert_equal '[Thomas et al. 2009; van Fraassen 1989]',
                 @bib.format('text').ref('pickaxe,fraassen_1989')

    assert_equal '[Thomas et al. 2009; van Fraassen 1989]',
                 @bib.format('text').ref('pickaxe,                 fraassen_1989')

    @book.config['bib-csl-style'] = 'apa'
    assert_equal '(Thomas et al., 2009; van Fraassen, 1989)',
                 @bib.format('text').ref('pickaxe,fraassen_1989')

    @book.config['bib-csl-style'] = 'ieee'
    assert_equal '[1, 2]',
                 @bib.format('text').ref('pickaxe,fraassen_1989')
  end

  def test_cite_html
    @book.config['bib-csl-style'] = 'acm-siggraph'
    assert_equal '[Thomas et al. 2009]', @bib.format('html').ref('pickaxe')

    @book.config['bib-csl-style'] = 'apa'
    assert_equal '(Thomas et al., 2009)', @bib.format('html').ref('pickaxe')
  end

  def test_ref_latex
    @book.config['bib-csl-style'] = 'acm-siggraph'
    assert_equal '[Thomas et al. 2009]', @bib.format('latex').ref('pickaxe')

    @book.config['bib-csl-style'] = 'apa'
    assert_equal '(Thomas et al., 2009)', @bib.format('latex').ref('pickaxe')
  end

  def test_list
    @book.config['bib-csl-style'] = 'acm-siggraph'
    expect = <<-EOS
Fraassen, B.C. van. 1989. Laws and Symmetry. Oxford University Press, Oxford.
Thomas, D. and Hunt, A. 2019. The Pragmatic Programmer: Your Journey to Mastery, 20th Anniversary Edition. The Pragmatic Bookshelf.
Thomas, D., Fowler, C., and Hunt, A. 2009. Programming Ruby 1.9: The Pragmatic Programmer’s Guide. The Pragmatic Bookshelf, Raleigh, North Carolina.
EOS
    assert_equal expect.chomp, @bib.format('text').list
  end

  def test_list_html
    @book.config['bib-csl-style'] = 'acm-siggraph'
    expect = <<-EOS
<ol class="csl-bibliography">
  <li class="csl-entry"><span style="font-variant: small-caps">Fraassen, B.C. van</span>. 1989. <i>Laws and Symmetry</i>. Oxford University Press, Oxford.</li>
  <li class="csl-entry"><span style="font-variant: small-caps">Thomas, D. and Hunt, A.</span> 2019. <i>The Pragmatic Programmer: Your Journey to Mastery, 20th Anniversary Edition</i>. The Pragmatic Bookshelf.</li>
  <li class="csl-entry"><span style="font-variant: small-caps">Thomas, D., Fowler, C., and Hunt, A.</span> 2009. <i>Programming Ruby 1.9: The Pragmatic Programmer’s Guide</i>. The Pragmatic Bookshelf, Raleigh, North Carolina.</li>
</ol>
EOS
    assert_equal expect.chomp, @bib.format('html').list

    @book.config['bib-csl-style'] = 'ieee'
    expect = <<-EOS
<ol class="csl-bibliography">
  <li class="csl-entry" style="margin-bottom: 0.0em">[1]D. Thomas, C. Fowler, and A. Hunt, <i>Programming Ruby 1.9: The Pragmatic Programmer’s Guide</i>. Raleigh, North Carolina: The Pragmatic Bookshelf, 2009.</li>
  <li class="csl-entry" style="margin-bottom: 0.0em">[2]B. C. van Fraassen, <i>Laws and Symmetry</i>. Oxford: Oxford University Press, 1989.</li>
  <li class="csl-entry" style="margin-bottom: 0.0em">[3]D. Thomas and A. Hunt, <i>The Pragmatic Programmer: Your Journey to Mastery, 20th Anniversary Edition</i>. The Pragmatic Bookshelf, 2019.</li>
</ol>
EOS
    assert_equal expect.chomp, @bib.format('html').list
  end

  def test_list_latex
    @book.config['bib-csl-style'] = 'acm-siggraph'
    expect = <<-EOS
\\begin{description}
\\item[] Fraassen, B.C. van. 1989. \\emph{Laws and Symmetry}. Oxford University Press, Oxford.
\\item[] Thomas, D. and Hunt, A. 2019. \\emph{The Pragmatic Programmer: Your Journey to Mastery, 20th Anniversary Edition}. The Pragmatic Bookshelf.
\\item[] Thomas, D., Fowler, C., and Hunt, A. 2009. \\emph{Programming Ruby 1.9: The Pragmatic Programmer’s Guide}. The Pragmatic Bookshelf, Raleigh, North Carolina.
\\end{description}
EOS
    assert_equal expect.chomp, @bib.format('latex').list

    @book.config['bib-csl-style'] = 'ieee'
    expect = <<-EOS
\\begin{description}
\\item[] [1]D. Thomas, C. Fowler, and A. Hunt, \\emph{Programming Ruby 1.9: The Pragmatic Programmer’s Guide}. Raleigh, North Carolina: The Pragmatic Bookshelf, 2009.
\\item[] [2]B. C. van Fraassen, \\emph{Laws and Symmetry}. Oxford: Oxford University Press, 1989.
\\item[] [3]D. Thomas and A. Hunt, \\emph{The Pragmatic Programmer: Your Journey to Mastery, 20th Anniversary Edition}. The Pragmatic Bookshelf, 2019.
\\end{description}
EOS
    assert_equal expect.chomp, @bib.format('latex').list
  end


  def test_sist02
    @book.config['bib-csl-style'] = 'sist02'
    key = 'pickaxe'

    # The sort order depends on the execution environment (OS).
    # Therefore if the reference number is the same, it is assumed to be passed.
    assert_equal @bib.format('text').list(key)[1], @bib.format('text').ref(key)[1]
  end

  private

  def bibfile
    <<-EOS
@book{pickaxe,
  address = {Raleigh, North Carolina},
  author = {Thomas, Dave and Fowler, Chad and Hunt, Andy},
  publisher = {The Pragmatic Bookshelf},
  series = {The Facets of Ruby},
  title = {Programming Ruby 1.9: The Pragmatic Programmer's Guide},
  year = {2009}
}
@book{fraassen_1989,
  Address = {Oxford},
  Author = {Bas C. van Fraassen},
  Publisher = {Oxford University Press},
  Title = {Laws and Symmetry},
  Year = 1989
}
@book{pragbook,
  author = {Thomas, Dave and Hunt, Andy},
  publisher = {The Pragmatic Bookshelf},
  title = {The Pragmatic Programmer: Your Journey to Mastery, 20th Anniversary Edition},
  year = {2019}
}
EOS
  end
end
