# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/topbuilder'
require 'review/i18n'

class TOPBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = TOPBuilder.new()
    @config = ReVIEW::Configure.values
    @config.merge!({
      "secnolevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "language" => "ja",
    })
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
    I18n.setup(@config["language"])
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|■H1■第1章　this is test.\n|, actual
  end

  def test_headline_level1_without_secno
    @config["secnolevel"] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|■H1■this is test.\n|, actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q|■H2■1.1　this is test.\n|, actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q|■H3■this is test.\n|, actual
  end

  def test_headline_level3_with_secno
    @config["secnolevel"] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q|■H3■1.0.1　this is test.\n|, actual
  end

  def test_href
    actual = compile_inline("@<href>{http://github.com, GitHub}")
    assert_equal %Q|GitHub（△http://github.com☆）|, actual
  end

  def test_href_without_label
    actual = compile_inline("@<href>{http://github.com}")
    assert_equal %Q|△http://github.com☆|, actual
  end

  def test_inline_raw
    actual = compile_inline("@<raw>{@<tt>{inline\}}")
    assert_equal %Q|@<tt>{inline}|, actual
  end

  def test_inline_ruby
    actual = compile_inline("@<ruby>{coffin,bed}")
    assert_equal %Q|coffin◆→DTP連絡:「coffin」に「bed」とルビ←◆|, actual
  end

  def test_inline_kw
    actual = compile_inline("@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}")
    assert_equal %Q|★ISO☆（International Organization for Standardization） ★Ruby<>☆|, actual
  end

  def test_inline_maru
    actual = compile_inline("@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}")
    assert_equal %Q|1◆→丸数字1←◆20◆→丸数字20←◆A◆→丸数字A←◆z◆→丸数字z←◆|, actual
  end

  def test_inline_br
    actual = compile_inline("@<br>{}")
    assert_equal %Q|\n|, actual
  end

  def test_inline_i
    actual = compile_inline("test @<i>{inline test} test2")
    assert_equal %Q|test ▲inline test☆ test2|, actual
  end

  def test_inline_i_and_escape
    actual = compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test ▲inline<&;\\ test☆ test2|, actual
  end

  def test_inline_b
    actual = compile_inline("test @<b>{inline test} test2")
    assert_equal %Q|test ★inline test☆ test2|, actual
  end

  def test_inline_b_and_escape
    actual = compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test ★inline<&;\\ test☆ test2|, actual
  end

  def test_inline_tt
    actual = compile_inline("test @<tt>{inline test} test2@<tt>{\\}}")
    assert_equal %Q|test △inline test☆ test2△}☆|, actual
  end

  def test_inline_tti
    actual = compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test ▲inline test☆◆→等幅フォントイタ←◆ test2|, actual
  end

  def test_inline_ttb
    actual = compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test ★inline test☆◆→等幅フォント太字←◆ test2|, actual
  end

  def test_inline_uchar
    actual = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test ① test2|, actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n★1☆\t▲2☆\n------------\n★3☆\t▲4☆<>&\n//}\n")
    assert_equal %Q|★★1☆☆\t★▲2☆☆\n★3☆\t▲4☆<>&\n◆→終了:表←◆\n\n|, actual
  end

  def test_paragraph
    actual = compile_block("foo\nbar\n")
    assert_equal %Q|foobar\n|, actual
  end

  def test_tabbed_paragraph
    actual = compile_block("\tfoo\nbar\n")
    assert_equal %Q|\tfoobar\n|, actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|◆→開始:右寄せ←◆\nfoobar\nbuz\n◆→終了:右寄せ←◆\n\n|, actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q|◆→DTP連絡:次の1行インデントなし←◆\nfoobar\nfoo2bar2\n|, actual
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("test",1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q|◆→開始:リスト←◆\nリスト1.1　this is ★test☆<&>_\n\nfoo\nbar\n◆→終了:リスト←◆\n\n|, actual
  end

  def test_listnum
    def @chapter.list(id)
      Book::ListIndex::Item.new("test",1)
    end
    actual = compile_block("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q|◆→開始:リスト←◆\nリスト1.1　this is ★test☆<&>_\n\n 1: foo\n 2: bar\n◆→終了:リスト←◆\n\n|, actual
  end

  def test_emlistnum
    actual = compile_block("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q|◆→開始:インラインリスト←◆\n■this is ★test☆<&>_\n 1: foo\n 2: bar\n◆→終了:インラインリスト←◆\n\n|, actual
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\nfoo\n//}\n")
    assert_equal %Q|◆→開始:図←◆\n図1.1　sample photo\n\n◆→./images/chap1-sampleimg.png←◆\n◆→終了:図←◆\n\n|, actual
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\nfoo\n//}\n")
    assert_equal %Q|◆→開始:図←◆\n図1.1　sample photo\n\n◆→./images/chap1-sampleimg.png←◆\n◆→終了:図←◆\n\n|, actual
  end

  def test_texequation
    actual = compile_block("//texequation{\n\\sin\n1^{2}\n//}\n")
    assert_equal %Q|◆→開始:TeX式←◆\n\\sin\n1^{2}\n◆→終了:TeX式←◆\n\n|, actual
  end

  def test_inline_raw0
    assert_equal "normal", compile_inline("@<raw>{normal}")
  end

  def test_inline_raw1
    assert_equal "body", compile_inline("@<raw>{|top|body}")
  end

  def test_inline_raw2
    assert_equal "body", compile_inline("@<raw>{|top, latex|body}")
  end

  def test_inline_raw3
    assert_equal "", compile_inline("@<raw>{|idgxml, html|body}")
  end

  def test_inline_raw4
    assert_equal "|top body", compile_inline("@<raw>{|top body}")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline("@<raw>{|top|nor\\nmal}")
  end

  def test_block_raw0
    actual = compile_block("//raw[<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw1
    actual = compile_block("//raw[|top|<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw2
    actual = compile_block("//raw[|top, latex|<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected.chomp, actual
  end

  def test_block_raw3
    actual = compile_block("//raw[|latex, idgxml|<>!\"\\n& ]\n")
    expected = ''
    assert_equal expected.chomp, actual
  end

  def test_block_raw4
    actual = compile_block("//raw[|top <>!\"\\n& ]\n")
    expected = %Q(|top <>!\"\n& )
    assert_equal expected.chomp, actual
  end

  def column_helper(review)
    compile_block(review)
  end

  def test_column_ref
    review =<<-EOS
===[column]{foo} test

inside column

=== next level

this is @<column>{foo}.
EOS
    expected =<<-EOS
◆→開始:コラム←◆
■test
inside column
◆→終了:コラム←◆

■H3■next level
this is test.
EOS

    assert_equal expected, column_helper(review)
  end

end
