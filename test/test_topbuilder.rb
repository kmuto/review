require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/topbuilder'
require 'review/i18n'

class TOPBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = TOPBuilder.new
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

    I18n.setup(@config['language'])
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(■H1■第1章　this is test.\n), actual
  end

  def test_headline_level1_without_secno
    @config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(■H1■this is test.\n), actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q(■H2■1.1　this is test.\n), actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(■H3■this is test.\n), actual
  end

  def test_headline_level3_with_secno
    @config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(■H3■1.0.1　this is test.\n), actual
  end

  def test_href
    actual = compile_inline('@<href>{http://github.com, GitHub}')
    assert_equal 'GitHub（△http://github.com☆）', actual
  end

  def test_href_without_label
    actual = compile_inline('@<href>{http://github.com}')
    assert_equal '△http://github.com☆', actual
  end

  def test_inline_raw
    actual = compile_inline('@<raw>{@<tt>{inline\}}')
    assert_equal '@<tt>{inline}', actual
  end

  def test_inline_ruby
    actual = compile_inline('@<ruby>{coffin,bed}')
    assert_equal 'coffin◆→DTP連絡:「coffin」に「bed」とルビ←◆', actual
  end

  def test_inline_kw
    actual = compile_inline('@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}')
    assert_equal '★ISO☆（International Organization for Standardization） ★Ruby<>☆', actual
  end

  def test_inline_maru
    actual = compile_inline('@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}')
    assert_equal '1◆→丸数字1←◆20◆→丸数字20←◆A◆→丸数字A←◆z◆→丸数字z←◆', actual
  end

  def test_inline_br
    actual = compile_inline('@<br>{}')
    assert_equal "\n", actual
  end

  def test_inline_i
    actual = compile_inline('test @<i>{inline test} test2')
    assert_equal 'test ▲inline test☆ test2', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test ▲inline<&;\\ test☆ test2', actual
  end

  def test_inline_b
    actual = compile_inline('test @<b>{inline test} test2')
    assert_equal 'test ★inline test☆ test2', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test ★inline<&;\\ test☆ test2', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2@<tt>{\\}}')
    assert_equal 'test △inline test☆ test2△}☆', actual
  end

  def test_inline_tti
    actual = compile_inline('test @<tti>{inline test} test2')
    assert_equal 'test ▲inline test☆◆→等幅フォントイタ←◆ test2', actual
  end

  def test_inline_ttb
    actual = compile_inline('test @<ttb>{inline test} test2')
    assert_equal 'test ★inline test☆◆→等幅フォント太字←◆ test2', actual
  end

  def test_inline_tcy
    actual = compile_inline('test @<tcy>{A} test2')
    assert_equal 'test ◆→開始:回転←◆A◆→終了:縦回転←◆ test2', actual
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
    assert_equal 'test ◆→コメント←◆ test2', actual
  end

  def test_inline_fence
    actual = compile_inline('@<m>|a|, @<m>{\\frac{1\\}{2\\}}, @<m>$\\frac{1}{2}$, @<m>{\\{ \\\\\\}}, @<m>|\\{ \\}|, test @<code>|@<code>{$サンプル$}|')
    assert_equal '◆→TeX式ここから←◆a◆→TeX式ここまで←◆, ◆→TeX式ここから←◆\\frac{1}{2}◆→TeX式ここまで←◆, ◆→TeX式ここから←◆\\frac{1}{2}◆→TeX式ここまで←◆, ◆→TeX式ここから←◆\\{ \\}◆→TeX式ここまで←◆, ◆→TeX式ここから←◆\\{ \\}◆→TeX式ここまで←◆, test △@<code>{$サンプル$}☆', actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n★1☆\t▲2☆\n------------\n★3☆\t▲4☆<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
★1☆\t▲2☆
------------
★3☆\t▲4☆<>&
◆→終了:表←◆

EOS
    assert_equal expected, actual
  end

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    expected = <<-EOS
★foo☆
\tfoo.

para

★foo☆
\tfoo.

1\tbar

★foo☆
\tfoo.

●\tbar

EOS
    assert_equal expected, actual
  end

  def test_dt_inline
    actual = compile_block("//footnote[bar][bar]\n\n : foo@<fn>{bar}[]<>&@<m>$\\alpha[]$\n")

    expected = <<-EOS
【注1】bar

★foo【注1】[]<>&◆→TeX式ここから←◆\\alpha[]◆→TeX式ここまで←◆☆
	

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
◆→開始:右寄せ←◆
foobar
buz
◆→終了:右寄せ←◆

EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
◆→開始:右寄せ←◆
foo bar
buz
◆→終了:右寄せ←◆

EOS
    assert_equal expected, actual
  end

  def test_blankline
    actual = compile_block("//blankline\nfoo\n")
    assert_equal %Q(\nfoo\n), actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
◆→DTP連絡:次の1行インデントなし←◆
foobar
foo2bar2
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
◆→DTP連絡:次の1行インデントなし←◆
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
    actual = compile_block('//comment[コメント<]')
    assert_equal %Q(◆→コメント<←◆\n), actual
    actual = compile_block("//comment{\nA<>\nB&\n//}")
    assert_equal %Q(◆→A<>\nB&←◆\n), actual
  end

  def test_list
    def @chapter.list(_id)
      Book::Index::Item.new('test', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:リスト←◆
リスト1.1　this is ★test☆<&>_

foo
bar
◆→終了:リスト←◆

EOS
    assert_equal expected, actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::Index::Item.new('test', 1)
    end
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:リスト←◆
リスト1.1　this is ★test☆<&>_

 1: foo
 2: bar
◆→終了:リスト←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:リスト←◆
 1: foo
 2: bar

リスト1.1　this is ★test☆<&>_
◆→終了:リスト←◆

EOS
    assert_equal expected, actual
  end

  def test_source
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
◆→開始:ソースコードリスト←◆
■foo/bar/test.rb
foo
bar

buz
◆→終了:ソースコードリスト←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
◆→開始:ソースコードリスト←◆
foo
bar

buz
■foo/bar/test.rb
◆→終了:ソースコードリスト←◆

EOS
    assert_equal expected, actual
  end

  def test_source_empty_caption
    actual = compile_block("//source[]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
◆→開始:ソースコードリスト←◆
foo
bar

buz
◆→終了:ソースコードリスト←◆

EOS
    assert_equal expected, actual
  end

  def test_box
    actual = compile_block("//box{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:書式←◆
foo
bar
◆→終了:書式←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//box[FOO]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:書式←◆
■FOO
foo
bar
◆→終了:書式←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//box[FOO]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:書式←◆
foo
bar
■FOO
◆→終了:書式←◆

EOS
    assert_equal expected, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
◆→開始:コマンド←◆
lineA
lineB
◆→終了:コマンド←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
◆→開始:コマンド←◆
■cap1
lineA
lineB
◆→終了:コマンド←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
◆→開始:コマンド←◆
lineA
lineB
■cap1
◆→終了:コマンド←◆

EOS
    assert_equal expected, actual
  end

  def test_emlist
    actual = compile_block("//emlist{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
◆→開始:インラインリスト←◆
lineA
lineB
◆→終了:インラインリスト←◆

EOS
    assert_equal expected, actual
  end

  def test_emlist_caption
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
◆→開始:インラインリスト←◆
■cap1
lineA
lineB
◆→終了:インラインリスト←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
◆→開始:インラインリスト←◆
lineA
lineB
■cap1
◆→終了:インラインリスト←◆

EOS
    assert_equal expected, actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:インラインリスト←◆
■this is ★test☆<&>_
 1: foo
 2: bar
◆→終了:インラインリスト←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
◆→開始:インラインリスト←◆
 1: foo
 2: bar
■this is ★test☆<&>_
◆→終了:インラインリスト←◆

EOS
    assert_equal expected, actual
  end

  def test_bib
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    assert_equal '[1]', compile_inline('@<bib>{samplebib}')
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
aaa\tbbb
------------
ccc\tddd<>&
◆→終了:表←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
表1.1　FOO

aaa\tbbb
------------
ccc\tddd<>&
◆→終了:表←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
aaa\tbbb
------------
ccc\tddd<>&

表1.1　FOO
◆→終了:表←◆

EOS
    assert_equal expected, actual
  end

  def test_table_th_bold
    @config['textmaker']['th_bold'] = true
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
★aaa☆\t★bbb☆
ccc\tddd<>&
◆→終了:表←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//table{\naaa\tbbb\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
★aaa☆\tbbb
★ccc☆\tddd<>&
◆→終了:表←◆

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
◆→開始:表←◆
foo

aaa\tbbb
------------
ccc\tddd<>&
◆→終了:表←◆

◆→開始:表←◆
aaa\tbbb
------------
ccc\tddd<>&
◆→終了:表←◆

EOS
    assert_equal expected, actual
  end

  def test_emtable_thbold
    @config['textmaker']['th_bold'] = true
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
◆→開始:表←◆
foo

★aaa☆\t★bbb☆
ccc\tddd<>&
◆→終了:表←◆

◆→開始:表←◆
★aaa☆\t★bbb☆
ccc\tddd<>&
◆→終了:表←◆

EOS
    assert_equal expected, actual
  end

  def test_table_row_separator
    src = "//table{\n1\t2\t\t3  4| 5\n------------\na b\tc  d   |e\n//}\n"
    expected = <<-EOS
◆→開始:表←◆
1	2	3  4| 5
------------
a b	c  d   |e	
◆→終了:表←◆

EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['table_row_separator'] = 'singletab'
    actual = compile_block(src)
    expected = <<-EOS
◆→開始:表←◆
1	2		3  4| 5
------------
a b	c  d   |e		
◆→終了:表←◆

EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'spaces'
    actual = compile_block(src)
    expected = <<-EOS
◆→開始:表←◆
1	2	3	4|	5
------------
a	b	c	d	|e
◆→終了:表←◆

EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'verticalbar'
    actual = compile_block(src)
    expected = <<-EOS
◆→開始:表←◆
1	2		3  4	5
------------
a b	c  d	e
◆→終了:表←◆

EOS
    assert_equal expected, actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:ノート←◆
A
B
◆→終了:ノート←◆

◆→開始:ノート←◆
■caption
A
◆→終了:ノート←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:メモ←◆
A
B
◆→終了:メモ←◆

◆→開始:メモ←◆
■caption
A
◆→終了:メモ←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:情報←◆
A
B
◆→終了:情報←◆

◆→開始:情報←◆
■caption
A
◆→終了:情報←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:重要←◆
A
B
◆→終了:重要←◆

◆→開始:重要←◆
■caption
A
◆→終了:重要←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:警告←◆
A
B
◆→終了:警告←◆

◆→開始:警告←◆
■caption
A
◆→終了:警告←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:注意←◆
A
B
◆→終了:注意←◆

◆→開始:注意←◆
■caption
A
◆→終了:注意←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:危険←◆
A
B
◆→終了:危険←◆

◆→開始:危険←◆
■caption
A
◆→終了:危険←◆

EOS
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = <<-EOS
◆→開始:TIP←◆
A
B
◆→終了:TIP←◆

◆→開始:TIP←◆
■caption
A
◆→終了:TIP←◆

EOS
    assert_equal expected, actual
  end

  def test_minicolumn_blocks
    titles = {
      'note' => 'ノート',
      'memo' => 'メモ',
      'important' => '重要',
      'info' => '情報',
      'notice' => '注意',
      'caution' => '警告',
      'warning' => '危険',
      'tip' => 'TIP'
    }

    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}[#{type}1]{

//}

//#{type}[#{type}2]{
//}
EOS

      expected = <<-EOS
◆→開始:#{titles[type]}←◆
■#{type}1
◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■#{type}2
◆→終了:#{titles[type]}←◆

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
◆→開始:#{titles[type]}←◆
■#{type}2
◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■#{type}3
◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■#{type}4
◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■#{type}5
◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■#{type}6
◆→終了:#{titles[type]}←◆

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
◆→開始:#{titles[type]}←◆

●	A

1	B

◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■OMITEND1

◆→開始:インラインリスト←◆
LIST
◆→終了:インラインリスト←◆

◆→終了:#{titles[type]}←◆

◆→開始:#{titles[type]}←◆
■OMITEND2
◆→終了:#{titles[type]}←◆

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
    expected = <<-EOS
◆→開始:図←◆
◆→./images/chap1-sampleimg.png←◆

図1.1　sample photo
◆→終了:図←◆

EOS
    assert_equal expected, actual

    @config['caption_position']['image'] = 'top'
    actual = compile_block("//image[sampleimg][sample photo]{\nfoo\n//}\n")
    expected = <<-EOS
◆→開始:図←◆
図1.1　sample photo

◆→./images/chap1-sampleimg.png←◆
◆→終了:図←◆

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
◆→開始:図←◆
◆→./images/chap1-sampleimg.png scale=1.2←◆

図1.1　sample photo
◆→終了:図←◆

EOS
    assert_equal expected, actual
  end

  def test_texequation
    actual = compile_block("//texequation{\n\\sin\n1^{2}\n//}\n")
    expected = <<-EOS
◆→開始:TeX式←◆
\\sin
1^{2}
◆→終了:TeX式←◆

EOS
    assert_equal expected, actual
  end

  def test_inline_w
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'words.csv'), <<EOB
"F","foo"
"B","bar""\\<>_@<b>{BAZ}"
EOB
      )
      @book.config['words_file'] = File.join(dir, 'words.csv')

      io = StringIO.new
      @builder.instance_eval { @logger = ReVIEW::Logger.new(io) }
      actual = compile_block('@<w>{F} @<w>{B} @<wb>{B} @<w>{N}')
      assert_equal %Q(foo bar"\\<>_@<b>{BAZ} ★bar"\\<>_@<b>{BAZ}☆ [missing word: N]\n), actual
      assert_match(/WARN --: :1: word not bound: N/, io.string)
    end
  end

  def test_endnote
    e = assert_raises(ReVIEW::ApplicationError) { compile_block("//endnote[foo][bar]\n\n@<endnote>{foo}\n") }
    assert_equal ':4: //endnote is found but //printendnotes is not found.', e.message

    actual = compile_block("@<endnote>{foo}\n//endnote[foo][bar]\n//printendnotes\n")
    expected = <<-'EOS'
【後注1】
◆→開始:後注←◆
【後注1】bar
◆→終了:後注←◆
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
    assert_equal 'body', compile_inline('@<raw>{|top|body}')
  end

  def test_inline_raw2
    assert_equal 'body', compile_inline('@<raw>{|top, latex|body}')
  end

  def test_inline_raw3
    assert_equal '', compile_inline('@<raw>{|idgxml, html|body}')
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
    assert_equal expected.chomp, actual
  end

  def test_block_raw1
    actual = compile_block(%Q(//raw[|top|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw2
    actual = compile_block(%Q(//raw[|top, latex|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw3
    actual = compile_block(%Q(//raw[|latex, idgxml|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected.chomp, actual
  end

  def test_block_raw4
    actual = compile_block(%Q(//raw[|top <>!"\\n& ]\n))
    expected = %Q(|top <>!"\n& )
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
◆→開始:コラム←◆
■test
inside column
◆→終了:コラム←◆

■H3■next level
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

◆→開始:TeX式←◆
式1.1　The Equivalence of Mass ▲and☆ Energy
e=mc^2
◆→終了:TeX式←◆

EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['caption_position']['equation'] = 'bottom'

    expected = <<-EOS
式1.1

◆→開始:TeX式←◆
e=mc^2
式1.1　The Equivalence of Mass ▲and☆ Energy
◆→終了:TeX式←◆

EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end
end
