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
    @book = Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
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

  def test_inline_sec
    def @chapter.headline_index
      item = Book::Index::Item.new('chap1|test', [1, 1], 'te_st<>')
      idx = Book::HeadlineIndex.new(self)
      idx.add_item(item)
      idx
    end

    @config['secnolevel'] = 3
    actual = compile_inline('test @<secref>{test}')
    assert_equal 'test 「1.1.1 te_st<>」', actual
    actual = compile_inline('test @<sectitle>{test}')
    assert_equal 'test te_st<>', actual
    actual = compile_inline('test @<sec>{test}')
    assert_equal 'test 1.1.1', actual

    @config['secnolevel'] = 2
    actual = compile_inline('test @<secref>{test}')
    assert_equal 'test 「te_st<>」', actual
    actual = compile_inline('test @<sectitle>{test}')
    assert_equal 'test te_st<>', actual
    assert_raises(ReVIEW::ApplicationError) { compile_block('test @<sec>{test}') }
    assert_match(/the target headline doesn't have a number/, @log_io.string)
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

  def test_inline_asis
    %w[i b tti ttb bou ami u strong em code ins tcy].each do |tag|
      actual = compile_inline("test @<#{tag}>{inline test} test2")
      assert_equal 'test inline test test2', actual
    end
  end

  def test_inline_del
    actual = compile_inline('test @<del>{inline test} test2')
    assert_equal 'test  test2', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test inline<&;\\ test test2', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test inline<&;\\ test test2', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2@<tt>{\\}}')
    assert_equal 'test inline test test2}', actual
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
    expected = <<-EOS
★1☆\t▲2☆
★3☆\t▲4☆<>&

EOS
    assert_equal expected, actual
  end

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    expected = <<-EOS
foo
foo.

para

foo
foo.

1　bar

foo
foo.

bar

EOS
    assert_equal expected, actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal %Q(foobar\n), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("foo\nbar\n")
    assert_equal %Q(foo bar\n), actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(\tfoobar\n), actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q(\tfoo bar\n), actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
foobar
buz

EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
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
    assert_equal '', actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_list
    def @chapter.list(_id)
      Book::Index::Item.new('test', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
リスト1.1　this is test<&>_

foo
bar

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
foo
bar

リスト1.1　this is test<&>_

EOS
    assert_equal expected, actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::Index::Item.new('test', 1)
    end
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
リスト1.1　this is test<&>_

 1: foo
 2: bar

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
 1: foo
 2: bar

リスト1.1　this is test<&>_

EOS
    assert_equal expected, actual
  end

  def test_source
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
foo/bar/test.rb
foo
bar

buz

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
foo
bar

buz
foo/bar/test.rb

EOS
    assert_equal expected, actual
  end

  def test_source_empty_caption
    actual = compile_block("//source[]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
foo
bar

buz

EOS
    assert_equal expected, actual
  end

  def test_box
    actual = compile_block("//box{\nfoo\nbar\n//}\n")
    expected = <<-EOS
foo
bar

EOS
    assert_equal expected, actual

    actual = compile_block("//box[FOO]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
FOO
foo
bar

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//box[FOO]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
foo
bar
FOO

EOS
    assert_equal expected, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
lineA
lineB

EOS
    assert_equal expected, actual

    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
cap1
lineA
lineB

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
lineA
lineB
cap1

EOS
    assert_equal expected, actual
  end

  def test_emlist
    actual = compile_block("//emlist{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
lineA
lineB

EOS
    assert_equal expected, actual
  end

  def test_emlist_caption
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
cap1
lineA
lineB

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
lineA
lineB
cap1

EOS
    assert_equal expected, actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
this is test<&>_
 1: foo
 2: bar

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
 1: foo
 2: bar
this is test<&>_

EOS
    assert_equal expected, actual
  end

  def test_bib
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    assert_equal '1 ', compile_inline('@<bib>{samplebib}')
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
aaa\tbbb
ccc\tddd<>&

EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
表1.1　FOO

aaa\tbbb
ccc\tddd<>&

EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
aaa\tbbb
ccc\tddd<>&

表1.1　FOO
EOS
    assert_equal expected, actual
  end

  def test_empty_table
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//table{\n//}\n") }
    assert_equal 'no rows in the table', e.message

    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//table{\n------------\n//}\n") }
    assert_equal 'no rows in the table', e.message
  end

  def test_inline_table
    def @chapter.table(_id)
      Book::Index::Item.new('sampletable', 1)
    end
    actual = compile_block("@<table>{sampletest}\n")
    assert_equal "表1.1\n", actual
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
foo

aaa\tbbb
ccc\tddd<>&

aaa\tbbb
ccc\tddd<>&

EOS
    assert_equal expected, actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = <<-EOS
A
B

caption
A

EOS
    assert_equal expected, actual
  end

  def test_minicolumn_blocks
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}[#{type}1]{

//}

//#{type}[#{type}2]{
//}
EOS

      expected = <<-EOS
#{type}1

#{type}2

EOS
      assert_equal expected, compile_block(src)

      src = <<-EOS
//#{type}[#{type}2]{

//}

//#{type}[#{type}3]{

//}

//#{type}[#{type}4]{

//}

//#{type}[#{type}5]{

//}

//#{type}[#{type}6]{

//}
EOS

      expected = <<-EOS
#{type}2

#{type}3

#{type}4

#{type}5

#{type}6

EOS
      assert_equal expected, compile_block(src)

      src = <<-EOS
//#{type}{

 * A

 1. B

//}

//#{type}[OMITEND1]{

//emlist{
LIST
//}

//}
//#{type}[OMITEND2]{
//}
EOS

      expected = <<-EOS
A

1　B

OMITEND1

LIST

OMITEND2

EOS
      assert_equal expected, compile_block(src)
    end
  end

  def test_minicolumn_blocks_nest_error1
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//#{type}{
//}

//}
EOS
      assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, @log_io.string)
    end
  end

  def test_minicolumn_blocks_nest_error2
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//#{type}{

//}

//}
EOS
      assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, @log_io.string)
    end
  end

  def test_minicolumn_blocks_nest_error3
    %w[memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//note{
//}

//}
EOS
      assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, @log_io.string)
    end
  end

  def test_image
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\nfoo\n//}\n")
    assert_equal %Q(図1.1　sample photo\n\n), actual

    @config['caption_position']['image'] = 'top'
    actual = compile_block("//image[sampleimg][sample photo]{\nfoo\n//}\n")
    assert_equal %Q(図1.1　sample photo\n\n), actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
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

  def test_endnote
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//endnote[foo][bar]\n\n@<endnote>{foo}\n") }
    assert_equal ':4: //endnote is found but //printendnotes is not found.', e.message

    actual = compile_block("@<endnote>{foo}\n//endnote[foo][bar]\n//printendnotes\n")
    expected = <<-'EOS'
(1)
(1) bar
EOS
    assert_equal expected, actual
  end

  def test_inline_unknown
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<img>{n}\n") }
    assert_match(/unknown image: n/, @log_io.string)

    @log_io.string = ''
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<fn>{n}\n") }
    assert_match(/unknown footnote: n/, @log_io.string)

    @log_io.string = ''
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<endnote>{n}\n") }
    assert_match(/unknown endnote: n/, @log_io.string)

    @log_io.string = ''
    assert_raises(ReVIEW::ApplicationError) { compile_block("@<hd>{n}\n") }
    assert_match(/unknown headline: n/, @log_io.string)
    %w[list table column].each do |name|
      @log_io.string = ''
      assert_raises(ReVIEW::ApplicationError) { compile_block("@<#{name}>{n}\n") }
      assert_match(/unknown #{name}: n/, @log_io.string)
    end
    %w[chap chapref title].each do |name|
      @log_io.string = ''
      assert_raises(ReVIEW::ApplicationError) { compile_block("@<#{name}>{n}\n") }
      assert_match(/key not found: "n"/, @log_io.string)
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
this is コラム「test」.
EOS

    assert_equal expected, column_helper(review)
  end

  def test_texequation_with_caption
    src = <<-EOS
@<eq>{emc2}

//texequation[emc2][The Equivalence of Mass @<i>{and} Energy]{
e=mc^2
//}
EOS
    expected = <<-EOS
式1.1

式1.1　The Equivalence of Mass and Energy
e=mc^2

EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['caption_position']['equation'] = 'bottom'
    expected = <<-EOS
式1.1

e=mc^2
式1.1　The Equivalence of Mass and Energy

EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_error_open
    src = <<-EOS
//endchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ":1: //endchild is shown, but any opened //beginchild doesn't exist", e.message
  end

  def test_nest_error_close1
    src = <<-EOS
//beginchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ":1: //beginchild is shown, but previous element isn't ul, ol, or dl", e.message
  end

  def test_nest_error_close2
    src = <<-EOS
 * foo

//beginchild

 1. foo

//beginchild

 : foo

//beginchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ':12: //beginchild of dl,ol,ul misses //endchild', e.message
  end

  def test_nest_error_close3
    src = <<-EOS
 * foo

//beginchild

 1. foo

//beginchild

 : foo

//beginchild

//endchild
EOS
    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ':14: //beginchild of ol,ul misses //endchild', e.message
  end

  def test_nest_ul
    src = <<-EOS
 * UL1

//beginchild

 1. UL1-OL1
 2. UL1-OL2

 * UL1-UL1
 * UL1-UL2

 : UL1-DL1
	UL1-DD1
 : UL1-DL2
	UL1-DD2

//endchild

 * UL2

//beginchild

UL2-PARA

//endchild
EOS

    expected = <<-EOS
UL1
	
	1　UL1-OL1
	2　UL1-OL2
	
	UL1-UL1
	UL1-UL2
	
	UL1-DL1
	UL1-DD1
	UL1-DL2
	UL1-DD2
	
UL2
	UL2-PARA
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_ol
    src = <<-EOS
 1. OL1

//beginchild

 1. OL1-OL1
 2. OL1-OL2

 * OL1-UL1
 * OL1-UL2

 : OL1-DL1
	OL1-DD1
 : OL1-DL2
	OL1-DD2

//endchild

 2. OL2

//beginchild

OL2-PARA

//endchild
EOS

    expected = <<-EOS
1　OL1
	
	1　OL1-OL1
	2　OL1-OL2
	
	OL1-UL1
	OL1-UL2
	
	OL1-DL1
	OL1-DD1
	OL1-DL2
	OL1-DD2
	
2　OL2
	OL2-PARA
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_dl
    src = <<-EOS
 : DL1

//beginchild

 1. DL1-OL1
 2. DL1-OL2

 * DL1-UL1
 * DL1-UL2

 : DL1-DL1
	DL1-DD1
 : DL1-DL2
	DL1-DD2

//endchild

 : DL2
	DD2

//beginchild

 * DD2-UL1
 * DD2-UL2

DD2-PARA

//endchild
EOS

    expected = <<-EOS
DL1
	
	1　DL1-OL1
	2　DL1-OL2
	
	DL1-UL1
	DL1-UL2
	
	DL1-DL1
	DL1-DD1
	DL1-DL2
	DL1-DD2
	
DL2
DD2
	
	DD2-UL1
	DD2-UL2
	
	DD2-PARA
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_nest_multi
    src = <<-EOS
 1. OL1

//beginchild

 1. OL1-OL1

//beginchild

 * OL1-OL1-UL1

OL1-OL1-PARA

//endchild

 2. OL1-OL2

 * OL1-UL1

//beginchild

 : OL1-UL1-DL1
	OL1-UL1-DD1

OL1-UL1-PARA

//endchild

 * OL1-UL2

//endchild
EOS
    expected = <<-EOS
1　OL1
	
	1　OL1-OL1
	
		
		OL1-OL1-UL1
		
		OL1-OL1-PARA
	
	2　OL1-OL2
	
	OL1-UL1
	
		
		OL1-UL1-DL1
		OL1-UL1-DD1
		
		OL1-UL1-PARA
	
	OL1-UL2
	
EOS

    actual = compile_block(src)
    assert_equal expected, actual
  end
end
