require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/rstbuilder'
require 'review/i18n'

class RSTBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = RSTBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = Book::Base.new
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)

    @builder.instance_eval do
      # to ignore lineno in original method
      def warn(msg)
        puts msg
      end
    end
    I18n.setup(@config['language'])
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    expected = <<-EOS
.. _test:

==========================
this is test.
==========================

EOS
    assert_equal expected, actual
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    expected = <<-EOS
.. _test:

==========================
this is test.
==========================

EOS
    assert_equal expected, actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    expected = <<-EOS
.. _test:

this is test.
==========================

EOS
    assert_equal expected, actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    expected = <<-EOS
.. _test:

this is test.
--------------------------

EOS
    assert_equal expected, actual
  end

  def test_headline_level3_with_secno
    @config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    expected = <<-EOS
.. _test:

this is test.
--------------------------

EOS
    assert_equal expected, actual
  end

  def test_href
    actual = compile_inline('@<href>{http://github.com, GitHub}')
    assert_equal %Q( `GitHub <http://github.com>`_ ), actual
  end

  def test_href_without_label
    actual = compile_inline('@<href>{http://github.com}')
    assert_equal ' `http://github.com <http://github.com>`_ ', actual
  end

  def test_inline_raw
    actual = compile_inline('@<raw>{@<tt>{inline\}}')
    assert_equal '@<tt>{inline}', actual
  end

  def test_inline_ruby
    actual = compile_inline('@<ruby>{coffin,bed}')
    assert_equal ' :ruby:`coffin`<bed>`_ ', actual
  end

  def test_inline_kw
    actual = compile_inline('@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}')
    assert_equal ' **ISO（International Organization for Standardization）**   **Ruby<>** ', actual
  end

  def test_inline_maru
    actual = compile_inline('@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}')
    assert_equal ' :maru:`1`  :maru:`20`  :maru:`A`  :maru:`z` ', actual
  end

  def test_inline_br
    actual = compile_inline('@<br>{}')
    assert_equal "\n", actual
  end

  def test_inline_i
    actual = compile_inline('test @<i>{inline test} test2')
    assert_equal 'test  *inline test*  test2', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test  *inline<&;\\ test*  test2', actual
  end

  def test_inline_b
    actual = compile_inline('test @<b>{inline test} test2')
    assert_equal 'test  **inline test**  test2', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test  **inline<&;\\ test**  test2', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2@<tt>{\\}}')
    assert_equal 'test  ``inline test``  test2 ``}`` ', actual
  end

  def test_inline_tti
    actual = compile_inline('test @<tti>{inline test} test2')
    assert_equal 'test  ``inline test``  test2', actual
  end

  def test_inline_ttb
    actual = compile_inline('test @<ttb>{inline test} test2')
    assert_equal 'test  ``inline test``  test2', actual
  end

  def test_inline_uchar
    actual = compile_inline('test @<uchar>{2460} test2')
    assert_equal 'test ① test2', actual
  end

  def test_inline_comment
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test  test2', actual
  end

  def test_inline_comment_for_draft
    @config['draft'] = true
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test コメント test2', actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n★1☆\t▲2☆\n------------\n★3☆\t▲4☆<>&\n//}\n")
    expected = <<-EOS
   * - ★1☆
     - ▲2☆
   * - ★3☆
     - ▲4☆<>&

EOS
    assert_equal expected, actual
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\nA\n//}\n//emtable{\nA\n//}")
    expected = <<-EOS
.. list-table:: foo
   :header-rows: 1

   * - A

   * - A

EOS
    assert_equal expected, actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal %Q(foobar\n\n), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("foo\nbar\n")
    assert_equal %Q(foo bar\n\n), actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(\tfoobar\n\n), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(\tfoo bar\n\n), actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
.. flushright::

   foobar
buz

EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
.. flushright::

   foo bar
buz

EOS
    assert_equal expected, actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
foobar

foo2bar2

EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
foo bar

foo2 bar2

EOS
    assert_equal expected, actual
  end

  def test_comment
    actual = compile_block('//comment[コメント]')
    assert_equal "\n", actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント]')
    assert_equal "\n", actual
  end

  def test_list
    def @chapter.list(_id)
      Book::Index::Item.new('test', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
.. _samplelist:

-foo
-bar
EOS
    assert_equal expected, actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::Index::Item.new('test', 1)
    end
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
.. _test:

1
2

EOS
    assert_equal expected, actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
this is @<b>{test}<&>_

.. code-block:: none
   :linenos:

   foo
   bar

EOS
    assert_equal expected, actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = <<-EOS
.. note::

   A

B


.. note::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = <<-EOS
.. memo::

   A

B


.. memo::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = <<-EOS
.. info::

   A

B


.. info::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = <<-EOS
.. important::

   A

B


.. important::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = <<-EOS
.. caution::

   A

B


.. caution::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = <<-EOS
.. notice::

   A

B


.. notice::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = <<-EOS
.. warning::

   A

B


.. warning::

   caption
   A


EOS
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = <<-EOS
.. tip::

   A

B


.. tip::

   caption
   A


EOS
    assert_equal expected, actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\nfoo\n//}\n")
    expected = <<-EOS
.. _sampleimg:

.. figure:: images/-/sampleimg.png

   sample photo

EOS
    assert_equal expected, actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\nfoo\n//}\n")
    expected = <<-EOS
.. _sampleimg:

.. figure:: images/-/sampleimg.png
   :scale:120.0%

   sample photo

EOS
    assert_equal expected, actual
  end

  def test_texequation
    actual = compile_block("//texequation{\n\\sin\n1^{2}\n//}\n")
    expected = <<-EOS
.. math::

   \\sin   1^{2}

EOS
    assert_equal expected, actual
  end

  def test_endnote
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//endnote[foo][bar]\n\n@<endnote>{foo}\n") }
    assert_equal '//endnote is found but //printendnotes is not found.', e.message

    actual = compile_block("@<endnote>{foo}\n//endnote[foo][bar]\n//printendnotes\n")
    expected = <<-'EOS'
 [(1)]_ 

.. [(1)] bar
EOS
    assert_equal expected, actual
  end

  def test_inline_raw0
    assert_equal 'normal', compile_inline('@<raw>{normal}')
  end

  def test_inline_raw1
    assert_equal 'body', compile_inline('@<raw>{|top|body}')
  end

  def test_inline_raw2
    assert_equal 'body', compile_inline('@<raw>{|top, latex|body}')
  end

  def test_inline_raw3
    assert_equal 'body', compile_inline('@<raw>{|idgxml, html|body}')
  end

  def test_inline_raw4
    assert_equal '|top body', compile_inline('@<raw>{|top body}')
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline('@<raw>{|top|nor\\nmal}')
  end

  def test_block_raw0
    actual = compile_block(%Q(//raw[<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw1
    actual = compile_block(%Q(//raw[|top|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw2
    actual = compile_block(%Q(//raw[|top, latex|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw3
    actual = compile_block(%Q(//raw[|latex, idgxml|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw4
    actual = compile_block(%Q(//raw[|top <>!"\\n& ]\n))
    expected = %Q(|top <>!"\n& )
    assert_equal expected, actual
  end

  def column_helper(review)
    compile_block(review)
  end

  def test_column_ref
    review = <<-EOS
===[column]{foo} test

inside column

=== next level

this is @<column>{foo}.
EOS
    expected = <<-EOS
.. column:: test

   inside column


next level
--------------------

this is コラム「test」.

EOS

    assert_equal expected, column_helper(review)
  end
end
