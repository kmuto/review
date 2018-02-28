require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/plaintextbuilder'
require 'review/i18n'

class PLAINTEXTBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = PLAINTEXTBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = Book::Base.new(nil)
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
    assert_equal %Q(第1章　this is test.\n), actual
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(this is test.\n), actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q(1.1　this is test.\n), actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(this is test.\n), actual
  end

  def test_headline_level3_with_secno
    @config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(1.0.1　this is test.\n), actual
  end

  def test_href
    actual = compile_inline('@<href>{http://github.com, GitHub}')
    assert_equal 'GitHub（http://github.com）', actual
  end

  def test_href_without_label
    actual = compile_inline('@<href>{http://github.com}')
    assert_equal 'http://github.com', actual
  end

  def test_inline_raw
    actual = compile_inline('@<raw>{@<tt>{inline\}}')
    assert_equal '@<tt>{inline}', actual
  end

  def test_inline_ruby
    actual = compile_inline('@<ruby>{coffin,bed}')
    assert_equal 'coffin', actual
  end

  def test_inline_kw
    actual = compile_inline('@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}')
    assert_equal 'ISO（International Organization for Standardization） Ruby<>', actual
  end

  def test_inline_maru
    actual = compile_inline('@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}')
    assert_equal '120Az', actual
  end

  def test_inline_br
    actual = compile_inline('@<br>{}')
    assert_equal "\n", actual
  end

  def test_inline_i
    actual = compile_inline('test @<i>{inline test} test2')
    assert_equal 'test inline test test2', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test inline<&;\\ test test2', actual
  end

  def test_inline_b
    actual = compile_inline('test @<b>{inline test} test2')
    assert_equal 'test inline test test2', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test inline<&;\\ test test2', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2@<tt>{\\}}')
    assert_equal 'test inline test test2}', actual
  end

  def test_inline_tti
    actual = compile_inline('test @<tti>{inline test} test2')
    assert_equal 'test inline test test2', actual
  end

  def test_inline_ttb
    actual = compile_inline('test @<ttb>{inline test} test2')
    assert_equal 'test inline test test2', actual
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
    assert_equal 'test  test2', actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n★1☆\t▲2☆\n------------\n★3☆\t▲4☆<>&\n//}\n")
    assert_equal %Q(★1☆\t▲2☆\n★3☆\t▲4☆<>&\n\n), actual
  end

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    assert_equal %Q(foo\nfoo.\n\npara\n\nfoo\nfoo.\n\n1　bar\n\nfoo\nfoo.\n\nbar\n\n), actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal %Q(foobar\n), actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(\tfoobar\n), actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(foobar\nbuz\n\n), actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q(foobar\nfoo2bar2\n), actual
  end

  def test_comment
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_list
    def @chapter.list(_id)
      Book::ListIndex::Item.new('test', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q(リスト1.1　this is test<&>_\n\nfoo\nbar\n\n), actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::ListIndex::Item.new('test', 1)
    end
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q(リスト1.1　this is test<&>_\n\n 1: foo\n 2: bar\n\n), actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q(this is test<&>_\n 1: foo\n 2: bar\n\n), actual
  end

  def test_bib
    def @chapter.bibpaper(_id)
      Book::BibpaperIndex::Item.new('samplebib', 1, 'sample bib')
    end

    assert_equal '1 ', compile_inline('@<bib>{samplebib}')
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    assert_equal %Q(aaa\tbbb\nccc\tddd<>&\n\n),
                 actual
  end

  def test_inline_table
    def @chapter.table(_id)
      Book::TableIndex::Item.new('sampletable', 1)
    end
    actual = compile_block("@<table>{sampletest}\n")
    assert_equal "表1.1\n", actual
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    assert_equal %Q(foo\n\naaa\tbbb\nccc\tddd<>&\n\naaa\tbbb\nccc\tddd<>&\n\n),
                 actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = %Q(A\nB\n\ncaption\nA\n\n)
    assert_equal expected, actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\nfoo\n//}\n")
    assert_equal %Q(図1.1　sample photo\n\n), actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::ImageIndex::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\nfoo\n//}\n")
    assert_equal %Q(図1.1　sample photo\n\n), actual
  end

  def test_texequation
    actual = compile_block("//texequation{\n\\sin\n1^{2}\n//}\n")
    assert_equal %Q(\\sin\n1^{2}\n\n), actual
  end

  def test_inline_unknown
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<img>{n}\n" }
    assert_equal ':1: error: unknown image: n', e.message
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<fn>{n}\n" }
    assert_equal ':1: error: unknown footnote: n', e.message
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<hd>{n}\n" }
    assert_equal ':1: error: unknown headline: n', e.message
    %w[list table column].each do |name|
      e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<#{name}>{n}\n" }
      assert_equal ":1: error: unknown #{name}: n", e.message
    end
    %w[chap chapref title].each do |name|
      e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<#{name}>{n}\n" }
      assert_equal ':1: error: key not found: "n"', e.message
    end
  end

  def test_inline_raw0
    assert_equal 'normal', compile_inline('@<raw>{normal}')
  end

  def test_inline_raw1
    assert_equal 'body', compile_inline('@<raw>{|plaintext|body}')
  end

  def test_inline_raw2
    assert_equal 'body', compile_inline('@<raw>{|plaintext, latex|body}')
  end

  def test_inline_raw3
    assert_equal '', compile_inline('@<raw>{|idgxml, html|body}')
  end

  def test_inline_raw4
    assert_equal '|plaintext body', compile_inline('@<raw>{|plaintext body}')
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline('@<raw>{|plaintext|nor\\nmal}')
  end

  def test_block_raw0
    actual = compile_block(%Q(//raw[<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw1
    actual = compile_block(%Q(//raw[|plaintext|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw2
    actual = compile_block(%Q(//raw[|plaintext, latex|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw3
    actual = compile_block(%Q(//raw[|latex, idgxml|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected.chomp, actual
  end

  def test_block_raw4
    actual = compile_block(%Q(//raw[|plaintext <>!"\\n& ]\n))
    expected = %Q(|plaintext <>!"\n& )
    assert_equal expected.chomp, actual
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
test
inside column

next level
this is test.
EOS

    assert_equal expected, column_helper(review)
  end
end
